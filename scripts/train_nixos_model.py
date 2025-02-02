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

class NixOSModelTrainer:
    def __init__(self, dataset_dir: str, output_dir: str, model_name: str = "TinyLlama/TinyLlama-1.1B-Chat-v1.0"):
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
            trust_remote_code=True
        )
        
        # Configure special tokens
        self.tokenizer.pad_token = self.tokenizer.eos_token
        self.model.config.pad_token_id = self.tokenizer.eos_token_id
        
    def load_datasets(self) -> List[Dict[str, str]]:
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
                                "prompt": f"<|user|>\n{prompt}\n<|assistant|>\n",
                                "response": f"{response}\n</s>"
                            })
        
        return training_data
    
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
        training_data = self.load_datasets()
        print(f"Loaded {len(training_data)} training examples")
        
        dataset = Dataset.from_pandas(pd.DataFrame(training_data))
        
        def preprocess(examples):
            return self.tokenizer(
                text=examples["prompt"],
                text_target=examples["response"],
                truncation=True,
                max_length=1024,
                padding="max_length",
                return_tensors="pt"
            )
        
        dataset = dataset.map(preprocess, batched=True, remove_columns=["prompt", "response"])
        
        training_args = TrainingArguments(
            output_dir=self.output_dir,
            num_train_epochs=5,
            per_device_train_batch_size=2,
            gradient_accumulation_steps=4,
            learning_rate=2e-5,
            weight_decay=0.01,
            fp16=True,
            optim="adafactor",
            gradient_checkpointing=True,
            logging_steps=50,
            save_strategy="steps",
            save_steps=500,
            eval_steps=500,
            evaluation_strategy="steps",
            max_steps=3000,
            report_to="none",
            ddp_find_unused_parameters=False
        )
        
        trainer = Trainer(
            model=self.model,
            args=training_args,
            train_dataset=dataset,
            eval_dataset=dataset,
            data_collator=DataCollatorForLanguageModeling(
                tokenizer=self.tokenizer,
                mlm=False
            ),
        )
        
        print("Starting training...")
        trainer.train()
        self.save_optimized_model()

    def save_optimized_model(self):
        self.model.save_pretrained(self.output_dir / "final_model")
        self.tokenizer.save_pretrained(self.output_dir / "final_model")
        
        # Quantization
        quantized_model = torch.quantization.quantize_dynamic(
            self.model,
            {torch.nn.Linear},
            dtype=torch.qint8
        )
        quantized_model.save_pretrained(self.output_dir / "quantized")
        print(f"Saved optimized models to {self.output_dir}")

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