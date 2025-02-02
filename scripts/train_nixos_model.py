#!/usr/bin/env python3
import json
import torch
import pandas as pd
from pathlib import Path
from datetime import datetime
from transformers import (
    AutoTokenizer, 
    AutoModelForCausalLM,
    TrainingArguments,
    Trainer,
    DataCollatorForLanguageModeling
)
from datasets import Dataset
from typing import List, Dict, Any, Tuple
from peft import LoraConfig, get_peft_model

class NixOSModelTrainer:
    def __init__(self, dataset_dir: str, output_dir: str, model_name: str = "facebook/opt-125m"):
        self.dataset_dir = Path(dataset_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True, parents=True)
        self.model_name = model_name
        
        print(f"Loading tokenizer and model from {model_name}...")
        self.tokenizer = AutoTokenizer.from_pretrained(
            model_name,
            padding_side="left",
            trust_remote_code=True
        )
        self.model = AutoModelForCausalLM.from_pretrained(
            model_name,
            torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
            device_map="auto",
            low_cpu_mem_usage=True
        )

        # LoRA Configuration
        lora_config = LoraConfig(
            r=8,
            lora_alpha=32,
            target_modules=["q_proj", "v_proj"],
            lora_dropout=0.05,
            bias="none",
            task_type="CAUSAL_LM"
        )
        self.model = get_peft_model(self.model, lora_config)
        
        # Jetson Optimierungen
        if torch.cuda.is_available():
            self.model = self.model.to("cuda")
            torch.backends.cuda.enable_flash_sdp(True)
            torch.backends.cuda.enable_mem_efficient_sdp(True)
        
        self.model.print_trainable_parameters()
        self.tokenizer.pad_token = self.tokenizer.eos_token
        self.model.config.pad_token_id = self.tokenizer.eos_token_id
        
    def load_datasets(self) -> Dataset:
        training_data = []
        dataset_files = [
            'nixos_concepts.jsonl',
            'nixos_advanced_concepts.jsonl',
            'nixos_training_tasks.jsonl',
            'nixos_practical_examples.jsonl',
            'nixos_troubleshooting.jsonl'
        ]
        
        for file in dataset_files:
            file_path = self.dataset_dir / file
            if file_path.exists():
                with open(file_path, 'r') as f:
                    for line in f:
                        data = json.loads(line)
                        pairs = self._format_data_for_training(data)
                        for prompt, response in pairs:
                            training_data.append({
                                "text": f"<|user|>\n{prompt}\n<|assistant|>\n{response}\n</s>"
                            })
        
        dataset = Dataset.from_pandas(pd.DataFrame(training_data))
        return dataset.train_test_split(test_size=0.1)
    
    def _format_data_for_training(self, data: dict) -> List[Tuple[str, str]]:
        pairs = []
        
        if "concept" in data:
            prompt = f"Explain the NixOS concept: {data['concept']}"
            pairs.append((prompt, data['explanation']))
        
        if "task" in data:
            pairs.append((data['input'], data['output']))
        
        if "category" in data and "examples" in data:
            for example in data["examples"]:
                prompt = f"Show me how to {example['description']}"
                response = []
                if "title" in example:
                    response.append(f"Title: {example['title']}")
                if "commands" in example:
                    response.append("Commands:\n" + "\n".join(example["commands"]))
                if "explanation" in example:
                    response.append("Explanation:\n" + example['explanation'])
                pairs.append((prompt, "\n\n".join(response)))
        
        if "issue" in data:
            prompt = f"How do I fix this NixOS issue: {data['issue']}"
            response = ["Follow these steps:"]
            response += [f"{i+1}. {step}" for i, step in enumerate(data['steps'])]
            response.append("\nCommon causes:\n" + "\n".join(data['common_causes']))
            pairs.append((prompt, "\n".join(response)))
        
        return pairs

    def train(self):
        dataset = self.load_datasets()
        print(f"Loaded {len(dataset['train'])} training examples")
        print(f"Using {len(dataset['test'])} validation examples")

        def preprocess(examples):
            return self.tokenizer(
                examples["text"],
                truncation=True,
                max_length=256,  # Reduziert für Jetson RAM
                padding="max_length",
                return_tensors="pt",
                add_special_tokens=True  # Spezielle Tokens explizit hinzufügen
        )
        
        tokenized_dataset = dataset.map(
            preprocess,
            batched=True,
            remove_columns=["text"],
            num_proc=1  # Reduziert für Jetson ARM Architektur
        )

        training_args = TrainingArguments(
            output_dir=self.output_dir,
            num_train_epochs=3,
            learning_rate=1e-5,
            fp16=torch.cuda.is_bf16_supported(),
            optim="adafactor",
            logging_steps=100,
            save_strategy="steps",
            save_steps=500,
            evaluation_strategy="steps",
            eval_steps=200,
            max_steps=2000,
            per_device_train_batch_size=1,  # Angepasst für 8GB RAM
            gradient_accumulation_steps=16,
            report_to="none",
            dataloader_num_workers=1,
            remove_unused_columns=True,
            gradient_checkpointing=False  # Aktiviert für Speicheroptimierung
        )

        trainer = Trainer(
            model=self.model,
            args=training_args,
            train_dataset=tokenized_dataset["train"],
            eval_dataset=tokenized_dataset["test"],
            data_collator=DataCollatorForLanguageModeling(
                tokenizer=self.tokenizer,
                mlm=False,
                pad_to_multiple_of=8
            ),
        )

        print("Starting training...")
        trainer.train()
        self.save_optimized_model()

    def save_optimized_model(self):
        # Quantisierung vor dem Speichern
        self.model = torch.quantization.quantize_dynamic(
            self.model,
            {torch.nn.Linear},
            dtype=torch.qint8
        )
        
        self.model.save_pretrained(self.output_dir / "quantized_model")
        self.tokenizer.save_pretrained(self.output_dir / "quantized_model")
        print(f"Saved optimized model to {self.output_dir}")

    def test_model(self, test_prompts: List[str]):
        generation_config = {
            "max_new_tokens": 1024,
            "temperature": 0.7,
            "top_p": 0.9,
            "repetition_penalty": 1.2,
            "do_sample": True,
            "pad_token_id": self.tokenizer.eos_token_id
        }
        
        print("\nTesting model with NixOS prompts:")
        for prompt in test_prompts:
            formatted_prompt = f"<|user|>\n{prompt}\n<|assistant|>\n"
            inputs = self.tokenizer(
                formatted_prompt,
                return_tensors="pt"
            ).to(self.model.device)
            
            outputs = self.model.generate(
                **inputs,
                **generation_config
            )
            
            response = self.tokenizer.decode(
                outputs[0][inputs.input_ids.shape[1]:],
                skip_special_tokens=True
            )
            
            print(f"\nPROMPT: {prompt}\nRESPONSE:\n{response}\n{'='*50}")

def main():
    trainer = NixOSModelTrainer(
        dataset_dir="/home/fr4iser/Documents/Git/NixOsControlCenter/datasets",
        output_dir="/home/fr4iser/Documents/Git/NixOsControlCenter/models"
    )
    
    # Train and save optimized model
    trainer.train()
    
    # Test with various prompts
    test_prompts = [
        "What is NixOS and how is it different from other Linux distributions?",
        "How do I create a Python development environment with Poetry in NixOS?",
        "Explain how to update a NixOS system using flakes.",
        "How do I debug a broken NixOS configuration?",
        "Create a basic flake.nix for a Python web server with FastAPI"
    ]
    
    trainer.test_model(test_prompts)

if __name__ == "__main__":
    main()