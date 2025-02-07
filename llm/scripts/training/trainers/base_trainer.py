#!/usr/bin/env python3
"""Base trainer class for NixOS model training."""
import logging
from pathlib import Path
from typing import Dict, Optional, Any, Union
from datasets import Dataset
from transformers import Trainer, TrainingArguments
from transformers.trainer_utils import get_last_checkpoint

from ...data.dataset_manager import DatasetManager
from ..modules.visualization import VisualizationManager

logger = logging.getLogger(__name__)

class NixOSBaseTrainer(Trainer):
    """Base trainer class for NixOS model training."""
    
    def __init__(self,
                 model_name: str,
                 model=None,
                 tokenizer=None,
                 dataset_manager: Optional[DatasetManager] = None,
                 visualizer: Optional[VisualizationManager] = None,
                 train_dataset: Optional[Dataset] = None,
                 eval_dataset: Optional[Dataset] = None,
                 output_dir: Optional[str] = None,
                 **kwargs):
        """Initialize base trainer.
        
        Args:
            model_name: Name or path of the model
            model: Optional model instance
            tokenizer: Optional tokenizer instance
            dataset_manager: Optional dataset manager instance
            visualizer: Optional visualization manager instance
            train_dataset: Optional training dataset
            eval_dataset: Optional evaluation dataset
            output_dir: Optional output directory for saving results
            **kwargs: Additional trainer arguments
        """
        self.model_name = model_name
        self.dataset_manager = dataset_manager
        self.visualizer = visualizer
        self.train_dataset = train_dataset
        self.eval_dataset = eval_dataset
        self.output_dir = output_dir or 'tmp_trainer'
        
        # Set up training arguments
        self.setup_training_args(**kwargs)
        
        # Remove our custom args from kwargs
        for key in ['model_name', 'dataset_manager', 'visualizer']:
            kwargs.pop(key, None)
        
        # Initialize parent class
        super().__init__(
            model=model,
            args=self.training_args,
            train_dataset=train_dataset,
            eval_dataset=eval_dataset,
            tokenizer=tokenizer,
            **kwargs
        )
        
    def setup_training_args(self, **kwargs) -> None:
        """Set up training arguments."""
        # Default training arguments
        default_args = {
            'output_dir': self.output_dir,
            'evaluation_strategy': 'epoch',
            'save_strategy': 'epoch',
            'per_device_train_batch_size': 4,
            'per_device_eval_batch_size': 4,
            'num_train_epochs': 3,
            'weight_decay': 0.01,
            'push_to_hub': False,
            'report_to': 'none',
        }
        
        # Get training config if provided
        training_config = kwargs.get('training', {})
        if training_config:
            # Update default args with training config
            default_args.update(training_config)
        
        # Store hyperparameters separately
        self.hyperparameters = kwargs.get('hyperparameters', {})
        self.resource_limits = kwargs.get('resource_limits', {})
        
        # Create TrainingArguments instance
        self.training_args = TrainingArguments(**default_args)
        
    def train(self, resume_from_checkpoint: Optional[Union[str, bool]] = None):
        """Train the model."""
        logger.info("Starting training...")
        try:
            # Check if we should resume from checkpoint
            if resume_from_checkpoint is None:
                resume_from_checkpoint = bool(get_last_checkpoint(self.output_dir))
                
            # Start training
            super().train(resume_from_checkpoint=resume_from_checkpoint)
            logger.info("Training completed successfully")
            
        except Exception as e:
            logger.error(f"Training error: {e}")
            raise
            
    def evaluate(self) -> Dict[str, float]:
        """Evaluate the model.
        
        Returns:
            Dict containing evaluation metrics
        """
        if not self.model:
            logger.error("Model not initialized")
            raise ValueError("Model not initialized")
            
        if not self.eval_dataset:
            logger.error("No evaluation dataset provided")
            raise ValueError("No evaluation dataset provided")
            
        logger.info("Starting evaluation...")
        try:
            metrics = super().evaluate()
            return metrics
        except Exception as e:
            logger.error(f"Evaluation error: {e}")
            raise
            
    def save_model(self, output_dir: str):
        """Save the model.
        
        Args:
            output_dir: Directory to save the model to
        """
        if not self.model:
            logger.error("Model not initialized")
            raise ValueError("Model not initialized")
            
        logger.info(f"Saving model to {output_dir}")
        try:
            self.model.save_pretrained(output_dir)
            logger.info("Model saved successfully")
        except Exception as e:
            logger.error(f"Error saving model: {e}")
            raise
