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
from ..data.dataset_manager import DatasetManager, DatasetFeedback
from ..data.dataset_improver import DatasetImprover
from ..visualization.training_visualizer import TrainingVisualizer
import logging
from datetime import datetime
import torch.cuda

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class NixOSModelTrainer:
    def __init__(self, model_name: str = "NixOS"):
        ProjectPaths.ensure_directories()
        self.dataset_dir = ProjectPaths.DATASET_DIR
        self.output_dir = ProjectPaths.MODELS_DIR
        self.current_model_dir = ProjectPaths.CURRENT_MODEL_DIR
        self.model_name = model_name
        self.base_model = "NixOS"
        self.best_loss = float('inf')
        self.patience = 3
        self.patience_counter = 0
        self.dataset_manager = DatasetManager()
        self.dataset_improver = DatasetImprover()
        self.visualizer = TrainingVisualizer()
        self.collected_feedback = []
        
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
                low_cpu_mem_usage=True,
                use_gradient_checkpointing=True  # Enable gradient checkpointing
            )
            base_model.config.pad_token_id = self.tokenizer.eos_token_id
            base_model.config.use_cache = False  # Required for gradient checkpointing
            
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
            
            # Load base model first with gradient checkpointing
            self.model = AutoModelForCausalLM.from_pretrained(
                "facebook/opt-125m",
                torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
                device_map="auto",
                low_cpu_mem_usage=True,
                use_gradient_checkpointing=True  # Enable gradient checkpointing
            )
            self.model.config.pad_token_id = self.tokenizer.eos_token_id
            self.model.config.use_cache = False  # Required for gradient checkpointing
            
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
        
        # Process concept datasets with validation
        concepts_dir = Path(self.dataset_dir) / 'concepts'
        if concepts_dir.exists():
            for dir_path in concepts_dir.glob('*'):
                if dir_path.is_dir():
                    for jsonl_file in dir_path.glob('*.jsonl'):
                        logger.info(f"Loading concept dataset: {jsonl_file.relative_to(self.dataset_dir)}")
                        
                        # Validate dataset before loading
                        success, error_msg = self.dataset_manager.process_dataset(jsonl_file)
                        if not success:
                            logger.warning(f"Dataset validation failed for {jsonl_file}: {error_msg}")
                            continue
                            
                        # Get dataset status
                        status = self.dataset_manager.get_dataset_status(jsonl_file)
                        logger.info(f"Dataset metrics: {status['metrics']}")
                        
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
                                            "text": f"### Question: {prompt}\n\n### Answer: {response}\n",
                                            "source_file": str(jsonl_file),
                                            "line_number": line_num
                                        })
                                except json.JSONDecodeError as e:
                                    logger.error(f"JSON decode error in {jsonl_file.name} at line {line_num}: {str(e)}")
                                    continue
                                except Exception as e:
                                    logger.error(f"Error processing {jsonl_file.name} at line {line_num}: {str(e)}")
                                    continue
        
        # Load other dataset categories when they become available
        other_categories = ['tasks', 'examples', 'troubleshooting', 'optimization']
        for category in other_categories:
            category_path = Path(self.dataset_dir) / category
            if category_path.exists():
                for jsonl_file in category_path.glob('**/*.jsonl'):
                    logger.info(f"Loading {category} dataset: {jsonl_file.relative_to(self.dataset_dir)}")
                    
                    # Validate dataset before loading
                    success, error_msg = self.dataset_manager.process_dataset(jsonl_file)
                    if not success:
                        logger.warning(f"Dataset validation failed for {jsonl_file}: {error_msg}")
                        continue
                        
                    # Get dataset status
                    status = self.dataset_manager.get_dataset_status(jsonl_file)
                    logger.info(f"Dataset metrics: {status['metrics']}")
                    
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
                                        "text": f"### Question: {prompt}\n\n### Answer: {response}\n",
                                        "source_file": str(jsonl_file),
                                        "line_number": line_num
                                    })
                            except json.JSONDecodeError as e:
                                logger.error(f"JSON decode error in {jsonl_file.name} at line {line_num}: {str(e)}")
                                continue
                            except Exception as e:
                                logger.error(f"Error processing {jsonl_file.name} at line {line_num}: {str(e)}")
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
    
    def _collect_prediction_feedback(self, prediction: str, expected: str, example_id: str) -> DatasetFeedback:
        """Collect feedback on model predictions for dataset improvement."""
        # Calculate basic similarity score
        pred_tokens = set(prediction.lower().split())
        exp_tokens = set(expected.lower().split())
        similarity = len(pred_tokens.intersection(exp_tokens)) / len(pred_tokens.union(exp_tokens))
        
        # Generate improvement suggestions
        suggestions = []
        if similarity < 0.5:
            suggestions.append("Content significantly different from expected")
        if len(prediction.split()) < len(expected.split()) * 0.7:
            suggestions.append("Response too brief")
        if len(prediction.split()) > len(expected.split()) * 1.5:
            suggestions.append("Response too verbose")
        if not any(ref in prediction.lower() for ref in ["example", "reference"]):
            suggestions.append("Missing examples or references")
            
        return DatasetFeedback(
            example_id=example_id,
            prediction=prediction,
            expected=expected,
            score=similarity,
            improvement_suggestions=suggestions,
            timestamp=datetime.now().isoformat()
        )

    class FeedbackTrainer(Trainer):
        def __init__(self, *args, dataset_manager=None, visualizer=None, **kwargs):
            super().__init__(*args, **kwargs)
            self.dataset_manager = dataset_manager
            self.visualizer = visualizer
            self.best_loss = float('inf')
            self.patience = 3
            self.patience_counter = 0

        def compute_loss(self, model, inputs, return_outputs=False):
            loss, outputs = super().compute_loss(model, inputs, return_outputs=True)
            
            # Collect training metrics
            metrics = {
                "train_loss": loss.item(),
                "learning_rate": self.optimizer.param_groups[0]["lr"],
                "batch_size": self.args.train_batch_size,
            }
            
            # Add GPU metrics if available
            if torch.cuda.is_available():
                metrics["gpu_memory_used"] = torch.cuda.memory_allocated() / 1024**3  # Convert to GB
                
            # Add dataset quality metrics
            if self.dataset_manager:
                dataset_metrics = self.dataset_manager.compute_dataset_metrics()
                metrics.update(dataset_metrics)
            
            # Save metrics for visualization
            if self.visualizer:
                self.visualizer.save_training_metrics(self.state.global_step, metrics)
            
            # Collect feedback during evaluation
            if self.state.is_local_process_zero and not self.state.is_training:
                batch_size = inputs["input_ids"].shape[0]
                for i in range(batch_size):
                    example_id = f"{inputs.get('source_file', 'unknown')}_{inputs.get('line_number', i)}"
                    prediction = self.tokenizer.decode(outputs.logits[i].argmax(dim=-1))
                    expected = self.tokenizer.decode(inputs["input_ids"][i])
                    
                    feedback = self._collect_prediction_feedback(prediction, expected, example_id)
                    if self.dataset_manager:
                        self.dataset_manager.add_feedback(Path(inputs.get('source_file', 'unknown')), feedback)
            
            if return_outputs:
                return loss, outputs
            return loss

        def evaluate(self, *args, **kwargs):
            output = super().evaluate(*args, **kwargs)
            
            # Add evaluation metrics
            if self.visualizer:
                metrics = {
                    "eval_loss": output["eval_loss"],
                    "step": self.state.global_step,
                }
                self.visualizer.save_training_metrics(self.state.global_step, metrics)
            
            return output

        def training_step(self, *args, **kwargs):
            loss = super().training_step(*args, **kwargs)
            # Dynamic batch size adjustment based on loss stability
            if not torch.isnan(loss).any():
                if loss < self.best_loss * 0.95:  # Significant improvement
                    self.args.train_batch_size = min(
                        self.args.train_batch_size + 1, 
                        32  # Maximum batch size
                    )
                elif loss > self.best_loss * 1.5:  # Significant degradation
                    self.args.train_batch_size = max(
                        self.args.train_batch_size - 1,
                        1  # Minimum batch size
                    )
                self.best_loss = min(self.best_loss, loss)
            return loss

        def evaluate(self, *args, **kwargs):
            output = super().evaluate(*args, **kwargs)
            
            # Add evaluation metrics
            if self.visualizer:
                metrics = {
                    "eval_loss": output["eval_loss"],
                    "step": self.state.global_step,
                }
                self.visualizer.save_training_metrics(self.state.global_step, metrics)
            
            return output

    def train(self):
        dataset = self.load_datasets()
        print(f"Loaded {len(dataset['train'])} training examples")
        print(f"Using {len(dataset['test'])} validation examples")
        
        # Dynamic batch size calculation based on available GPU memory
        if torch.cuda.is_available():
            gpu_mem = torch.cuda.get_device_properties(0).total_memory
            batch_size = max(1, int(gpu_mem / (1024 * 1024 * 1024) * 2))
            print(f"Using dynamic batch size: {batch_size}")
        else:
            batch_size = 4
            print("Using CPU batch size: 4")

        training_args = TrainingArguments(
            output_dir=self.output_dir,
            num_train_epochs=3,
            per_device_train_batch_size=batch_size,
            per_device_eval_batch_size=batch_size,
            gradient_accumulation_steps=4,
            evaluation_strategy="steps",
            eval_steps=50,
            logging_dir=f"{self.output_dir}/logs",
            learning_rate=3e-4,
            weight_decay=0.01,
            warmup_steps=100,
            save_strategy="steps",
            save_steps=50,
            load_best_model_at_end=True,
            metric_for_best_model="eval_loss",
            greater_is_better=False,
            save_total_limit=3,
            fp16=torch.cuda.is_available(),
            report_to="none"
        )

        trainer = self.FeedbackTrainer(
            model=self.model,
            args=training_args,
            train_dataset=dataset["train"],
            eval_dataset=dataset["test"],
            data_collator=DataCollatorForLanguageModeling(
                tokenizer=self.tokenizer,
                mlm=False
            ),
            dataset_manager=self.dataset_manager,
            visualizer=self.visualizer
        )

        print("Starting training...")
        trainer.train()
        
        # After training, analyze feedback and improve datasets
        self._improve_datasets()
        
    def _improve_datasets(self):
        """Analyze feedback and improve datasets based on training results."""
        logger.info("Analyzing training feedback and improving datasets...")
        
        # Process each dataset file
        for dataset_path in Path(self.dataset_dir).rglob('*.jsonl'):
            if dataset_path.is_file():
                try:
                    # Generate improvements based on patterns and feedback
                    improvements = self.dataset_improver.generate_improvements(
                        dataset_path,
                        self.collected_feedback
                    )
                    
                    if improvements:
                        # Apply improvements and generate report
                        self.dataset_improver.apply_improvements(improvements)
                        report = self.dataset_improver.generate_improvement_report(improvements)
                        logger.info(f"\nImprovements for {dataset_path.name}:\n{report}")
                    else:
                        logger.info(f"No improvements needed for {dataset_path.name}")
                        
                except Exception as e:
                    logger.error(f"Error improving dataset {dataset_path}: {str(e)}")
                    continue
        
        logger.info("Dataset improvement process completed")
        
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
    
    # Start visualization server
    print("\nStarting visualization server...")
    import subprocess
    import sys
    
    viz_process = subprocess.Popen([
        sys.executable, "-m", "streamlit", "run",
        str(Path(__file__).parent.parent / "visualization" / "training_visualizer.py"),
        "--server.port=8501", "--server.address=localhost"
    ])
    
    print("Visualization dashboard available at: http://localhost:8501")
    
    trainer.train()  # This will automatically save after training

if __name__ == "__main__":
    main()
