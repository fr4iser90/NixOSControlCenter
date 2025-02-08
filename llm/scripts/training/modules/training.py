"""Module for managing the training process."""
from transformers import (
    TrainingArguments,
    Trainer,
    DataCollatorForLanguageModeling
)
import torch
import logging
from pathlib import Path
from typing import Dict, Any, Optional, Type
from ..trainers import LoRATrainer

logger = logging.getLogger(__name__)

class TrainingManager:
    """Handles model training and checkpointing."""
    
    def __init__(self, model_name: str, output_dir: Path, test_mode: bool = False):
        """Initialize training manager."""
        self.model_name = model_name
        self.output_dir = output_dir
        self.test_mode = test_mode
        
    def setup_training_args(self, config: Dict[str, Any] = None) -> TrainingArguments:
        """Set up training arguments with defaults or custom config."""
        default_config = {
            "output_dir": str(self.output_dir),
            "num_train_epochs": 3 if self.test_mode else 10,
            "per_device_train_batch_size": 1 if self.test_mode else 2,  # Reduced for Jetson
            "per_device_eval_batch_size": 1 if self.test_mode else 2,   # Reduced for Jetson
            "gradient_accumulation_steps": 4,  # Increased to compensate for smaller batch
            "evaluation_strategy": "steps",
            "eval_steps": 500,  # Further increased to reduce overhead
            "save_strategy": "steps",
            "save_steps": 500,  # Further increased to reduce overhead
            "save_total_limit": 2,  # Reduced to save disk space
            "learning_rate": 3e-4,
            "warmup_steps": 25,  # Reduced for faster start
            "logging_steps": 50,  # Increased to reduce overhead
            "optim": "adamw_torch",
            "lr_scheduler_type": "cosine",
            "report_to": "none",
            "fp16": True,  # Always use mixed precision on Jetson
            "gradient_checkpointing": True,
            "torch_compile": False,
            # Jetson-specific optimizations
            "dataloader_num_workers": 2,     # Use some parallel loading but not too much
            "dataloader_pin_memory": True,   # Speed up data transfer to GPU
            "max_grad_norm": 0.3,           # Help stabilize training
            "weight_decay": 0.01,           # Help prevent overfitting
            # Security settings
            "weights_only": True,           # Prevent arbitrary code execution during loading
        }
        
        if config:
            default_config.update(config)
            
        return TrainingArguments(**default_config)
        
    def initialize_trainer(
        self,
        model,
        train_dataset,
        eval_dataset,
        processing_class: Optional[Type] = None,
        tokenizer = None,  # Keep for backward compatibility
        training_args: TrainingArguments = None,
        callbacks: list = None
    ) -> Trainer:
        """Initialize the trainer with all components."""
        if training_args is None:
            training_args = self.setup_training_args()
            
        # Initialize data collator
        data_collator = DataCollatorForLanguageModeling(
            tokenizer=tokenizer,
            mlm=False
        )
        
        # Create trainer
        trainer = LoRATrainer(
            model=model,
            args=training_args,
            train_dataset=train_dataset,
            eval_dataset=eval_dataset,
            data_collator=data_collator,
            callbacks=callbacks or [],
            processing_class=processing_class or (tokenizer.__class__ if tokenizer else None)
        )
        
        return trainer
        
    def train_model(self, trainer: Trainer):
        """Train the model using the initialized trainer."""
        try:
            logger.info("Starting model training...")
            trainer.train()
            logger.info("Training completed successfully")
            return True
        except Exception as e:
            logger.error(f"Error during training: {e}")
            return False
            
    def save_checkpoints(self, trainer: Trainer, save_dir: Path = None):
        """Save model checkpoints."""
        if save_dir is None:
            save_dir = self.output_dir
            
        try:
            logger.info(f"Saving model to {save_dir}")
            trainer.save_model(str(save_dir))
            logger.info("Model saved successfully")
            return True
        except Exception as e:
            logger.error(f"Error saving model: {e}")
            return False
            
    @staticmethod
    def get_device_config():
        """Get device configuration based on available hardware."""
        return {
            "dtype": torch.float16 if torch.cuda.is_available() else torch.float32,
            "device_map": "auto",
            "low_cpu_mem_usage": True
        }
