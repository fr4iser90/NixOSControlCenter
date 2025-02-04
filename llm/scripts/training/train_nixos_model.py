#!/usr/bin/env python3
import json
import torch
import os
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
from ..utils.path_config import ProjectPaths

class NixOSModelTrainer:
    def __init__(self, model_name: str = "NixOS"):
        ProjectPaths.ensure_directories()
        self.dataset_dir = ProjectPaths.DATASET_DIR
        self.output_dir = ProjectPaths.MODELS_DIR
        self.current_model_dir = ProjectPaths.CURRENT_MODEL_DIR
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
        
    def load_datasets(self):
        """Load and prepare datasets for training"""
        training_data = []
        
        # Process concept datasets
        concepts_dir = Path(self.dataset_dir) / 'concepts'
        if concepts_dir.exists():
            for dir_path in concepts_dir.glob('*'):
                if dir_path.is_dir():
                    for jsonl_file in dir_path.glob('*.jsonl'):
                        print(f"Loading concept dataset: {jsonl_file.relative_to(self.dataset_dir)}")
                        with open(jsonl_file, 'r', encoding='utf-8') as f:
                            for line_num, line in enumerate(f, 1):
                                line = line.strip()
                                if not line:  # Skip empty lines
                                    continue
                                try:
                                    data = json.loads(line)
                                    pairs = self._format_data_for_training(data)
                                    for prompt, response in pairs:
                                        training_data.append({
                                            "text": f"### Question: {prompt}\n\n### Answer: {response}\n"
                                        })
                                except json.JSONDecodeError as e:
                                    print(f"Warning: JSON decode error in {jsonl_file.name} at line {line_num}: {str(e)}")
                                    print(f"Problematic line: {line[:100]}...")  # Print first 100 chars of the line
                                    continue
                                except Exception as e:
                                    print(f"Warning: Error processing {jsonl_file.name} at line {line_num}: {str(e)}")
                                    continue
        
        # Load other dataset categories when they become available
        other_categories = ['tasks', 'examples', 'troubleshooting', 'optimization']
        for category in other_categories:
            category_path = Path(self.dataset_dir) / category
            if category_path.exists():
                for jsonl_file in category_path.glob('**/*.jsonl'):
                    print(f"Loading {category} dataset: {jsonl_file.relative_to(self.dataset_dir)}")
                    with open(jsonl_file, 'r', encoding='utf-8') as f:
                        for line_num, line in enumerate(f, 1):
                            line = line.strip()
                            if not line:  # Skip empty lines
                                continue
                            try:
                                data = json.loads(line)
                                pairs = self._format_data_for_training(data)
                                for prompt, response in pairs:
                                    training_data.append({
                                        "text": f"### Question: {prompt}\n\n### Answer: {response}\n"
                                    })
                            except json.JSONDecodeError as e:
                                print(f"Warning: JSON decode error in {jsonl_file.name} at line {line_num}: {str(e)}")
                                print(f"Problematic line: {line[:100]}...")  # Print first 100 chars of the line
                                continue
                            except Exception as e:
                                print(f"Warning: Error processing {jsonl_file.name} at line {line_num}: {str(e)}")
                                continue
        
        if not training_data:
            raise ValueError("No training data was loaded. Check that the dataset files exist and are properly formatted.")
            
        # Convert to Dataset format
        dataset = Dataset.from_list(training_data)
        
        # Tokenize the dataset
        tokenized_dataset = dataset.map(
            self.preprocess,
            batched=True,
            remove_columns=dataset.column_names
        )
        
        return tokenized_dataset.train_test_split(test_size=0.1)
    
    def _format_data_for_training(self, data: dict) -> List[Tuple[str, str]]:
        pairs = []
        
        # Handle concept format
        if "concept" in data:
            # Main concept Q&A
            prompt = data['concept']
            response = [data['explanation']]
            
            # Add examples if available
            if 'examples' in data and data['examples']:
                response.append("\nExamples:")
                for example in data['examples']:
                    response.append(f"- {example}")
            
            # Add references if available
            if 'references' in data and data['references']:
                response.append("\nReferences:")
                for ref in data['references']:
                    response.append(f"- {ref}")
            
            pairs.append((prompt, "\n".join(response)))
        
        # Handle task format (when implemented)
        elif "task" in data:
            pairs.append((data['input'], data['output']))
        
        # Handle example format (when implemented)
        elif "example" in data:
            prompt = f"Show me an example of: {data['title']}"
            response = []
            if "description" in data:
                response.append(f"Description: {data['description']}")
            if "code" in data:
                response.append("Code:\n```nix\n" + data['code'] + "\n```")
            if "explanation" in data:
                response.append(f"Explanation: {data['explanation']}")
            pairs.append((prompt, "\n\n".join(response)))
        
        # Handle troubleshooting format (when implemented)
        elif "issue" in data:
            prompt = f"How do I fix this NixOS issue: {data['issue']}"
            response = []
            if "solution" in data:
                response.append(f"Solution: {data['solution']}")
            if "steps" in data:
                response.append("\nSteps:")
                for i, step in enumerate(data['steps'], 1):
                    response.append(f"{i}. {step}")
            if "notes" in data:
                response.append(f"\nNotes: {data['notes']}")
            pairs.append((prompt, "\n".join(response)))
        
        # Handle optimization format (when implemented)
        elif "optimization" in data:
            prompt = f"How can I optimize: {data['target']}"
            response = []
            if "suggestion" in data:
                response.append(f"Suggestion: {data['suggestion']}")
            if "implementation" in data:
                response.append("Implementation:\n```nix\n" + data['implementation'] + "\n```")
            if "benefits" in data:
                response.append(f"Benefits: {data['benefits']}")
            pairs.append((prompt, "\n\n".join(response)))
        
        return pairs

    def preprocess(self, examples):
        return self.tokenizer(
            examples["text"],
            truncation=True,
            max_length=512,
            padding="max_length",
            return_tensors=None
        )
    
    def train(self):
        dataset = self.load_datasets()
        print(f"Loaded {len(dataset['train'])} training examples")
        print(f"Using {len(dataset['test'])} validation examples")

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
            train_dataset=dataset["train"],
            eval_dataset=dataset["test"],
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

def get_user_home():
    return Path(os.getenv("HOME", "/default/path"))

def main():
    # Initialize trainer with paths from config
    trainer = NixOSModelTrainer()
    trainer.train()  # This will automatically save after training

if __name__ == "__main__":
    main()
