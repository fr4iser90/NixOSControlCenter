#!/usr/bin/env python3
import json
import torch
import pandas as pd
from pathlib import Path
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
    def __init__(self, dataset_dir: str, output_dir: str, model_name: str = "NixOS"):
        self.dataset_dir = Path(dataset_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True, parents=True)
        self.model_name = model_name
        self.base_model = "NixOS"
        
        # First check if we're loading an existing model
        if Path(model_name).exists() and (Path(model_name) / "adapter_model.safetensors").exists():
            print(f"Loading existing NixOS model from {model_name}...")
            # Load tokenizer from existing model
            self.tokenizer = AutoTokenizer.from_pretrained(
                model_name,
                padding_side="left",
                trust_remote_code=True
            )
            self.tokenizer.pad_token = self.tokenizer.eos_token
            
            # Load our trained model directly
            print(f"Loading NixOS model...")
            base_model = AutoModelForCausalLM.from_pretrained(
                "facebook/opt-125m",  # Load base model first
                torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
                device_map="auto",
                low_cpu_mem_usage=True
            )
            base_model.config.pad_token_id = self.tokenizer.eos_token_id
            
            # Apply LoRA config
            lora_config = LoraConfig(
                r=8,
                lora_alpha=32,
                target_modules=["q_proj", "v_proj"],
                lora_dropout=0.05,
                bias="none",
                task_type="CAUSAL_LM"
            )
            
            # Create PEFT model and load trained weights
            self.model = get_peft_model(base_model, lora_config)
            self.model.load_adapter(model_name, adapter_name="default")
            print("Loaded existing LoRA weights")
            
        else:
            # For new models, we still need to start from opt-125m
            print(f"Creating new NixOS model based on facebook/opt-125m...")
            self.tokenizer = AutoTokenizer.from_pretrained(
                "facebook/opt-125m",
                padding_side="left",
                trust_remote_code=True
            )
            self.tokenizer.pad_token = self.tokenizer.eos_token
            
            # Load base model first
            self.model = AutoModelForCausalLM.from_pretrained(
                "facebook/opt-125m",
                torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
                device_map="auto",
                low_cpu_mem_usage=True
            )
            self.model.config.pad_token_id = self.tokenizer.eos_token_id
            
            # Apply LoRA config
            lora_config = LoraConfig(
                r=8,
                lora_alpha=32,
                target_modules=["q_proj", "v_proj"],
                lora_dropout=0.05,
                bias="none",
                task_type="CAUSAL_LM"
            )
            
            print("Applying LoRA configuration...")
            self.model = get_peft_model(self.model, lora_config)
            self.model.print_trainable_parameters()
        
        # Move to GPU if available
        if torch.cuda.is_available():
            self.model = self.model.to("cuda")
            torch.backends.cuda.enable_flash_sdp(True)
            torch.backends.cuda.enable_mem_efficient_sdp(True)
        
    def load_datasets(self) -> Dataset:
        training_data = []
        dataset_files = [
            'nixos_concepts.jsonl',
            'nixos_advanced_concepts.jsonl',
            'nixos_training_tasks.jsonl',
            'nixos_practical_examples.jsonl',
            'nixos_troubleshooting.jsonl'
        ]
        
        # Load regular datasets
        for file in dataset_files:
            file_path = self.dataset_dir / file
            if file_path.exists():
                with open(file_path, 'r') as f:
                    for line in f:
                        data = json.loads(line)
                        pairs = self._format_data_for_training(data)
                        for prompt, response in pairs:
                            training_data.append({
                                "text": f"### Question: {prompt}\n\n### Answer: {response}\n"
                            })
        
        # Load optimization datasets
        optimization_files = list(self.dataset_dir.glob('nixos_optimization_dataset_*.json'))
        for file_path in optimization_files:
            print(f"Loading optimization dataset: {file_path.name}")
            with open(file_path, 'r') as f:
                data = json.load(f)
                for item in data:
                    # Format hardware profile
                    hw_profile = item['input']['hardware_profile']
                    hw_str = f"System: CPU={hw_profile['cpu_model']}, GPU={hw_profile['gpu_model']}, " \
                            f"Memory={hw_profile['memory_gb']}GB, Storage={hw_profile['storage_type']}"
                    
                    # Format performance metrics
                    metrics = item['input']['performance_metrics']
                    metrics_str = f"Current Metrics: CPU Usage={metrics['cpu_usage']}%, " \
                                f"Memory Usage={metrics['memory_usage']['percent']}%, " \
                                f"Disk IO: Read={metrics['disk_io']['read_bytes']}, Write={metrics['disk_io']['write_bytes']}"
                    
                    # Format requirements
                    reqs = item['input']['requirements']
                    reqs_str = f"Purpose: {reqs['purpose']}, Priorities: {', '.join(reqs['priorities'])}"
                    
                    # Create prompt
                    prompt = f"Optimize this NixOS configuration for the following system:\n\n" \
                            f"{hw_str}\n{metrics_str}\n{reqs_str}\n\n" \
                            f"Current configuration:\n```nix\n{item['input']['current_config']['content']}\n```"
                    
                    # Create response with optimizations and rationale
                    response = f"Here's the optimized configuration:\n\n```nix\n{item['output']['optimized_config']['content']}\n```\n\n" \
                              f"Improvements:\n{item['output']['rationale']}"
                    
                    training_data.append({
                        "text": f"### Question: {prompt}\n\n### Answer: {response}\n"
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
                max_length=512,
                padding="max_length",
                return_tensors=None
            )
        
        tokenized_dataset = dataset.map(
            preprocess,
            batched=True,
            remove_columns=dataset["train"].column_names,
            num_proc=1
        )

        training_args = TrainingArguments(
            output_dir=self.output_dir,
            num_train_epochs=3,
            learning_rate=1e-4,
            fp16=torch.cuda.is_available(),
            optim="adamw_torch",
            logging_steps=100,
            save_strategy="epoch",
            evaluation_strategy="epoch",
            per_device_train_batch_size=4,
            gradient_accumulation_steps=4,
            warmup_steps=100,
            weight_decay=0.01,
            report_to="none"
        )

        trainer = Trainer(
            model=self.model,
            args=training_args,
            train_dataset=tokenized_dataset["train"],
            eval_dataset=tokenized_dataset["test"],
            data_collator=DataCollatorForLanguageModeling(
                tokenizer=self.tokenizer,
                mlm=False
            )
        )

        print("Starting training...")
        trainer.train()
        self.save_model()

    def save_model(self):
        model_path = self.output_dir / "nixos_model"
        model_path.mkdir(parents=True, exist_ok=True)
        
        # Save the model state
        self.model.save_pretrained(model_path)
        self.tokenizer.save_pretrained(model_path)
        print(f"Saved model to {model_path}")

def main():
    trainer = NixOSModelTrainer(
        dataset_dir="/home/fr4iser/Documents/Git/NixOsControlCenter/datasets",
        output_dir="/home/fr4iser/Documents/Git/NixOsControlCenter/models"
    )
    
    # Train the model
    trainer.train()  # This will automatically save after training

if __name__ == "__main__":
    main()
