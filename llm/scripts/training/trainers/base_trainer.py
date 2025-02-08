#!/usr/bin/env python3
"""Base trainer class for NixOS model training."""
import logging
from pathlib import Path
from typing import Dict, Optional, Any, Union
from datasets import Dataset
from transformers import Trainer, TrainingArguments, TrainerState
from transformers.trainer_utils import get_last_checkpoint
from typing import TYPE_CHECKING

from ...data.dataset_manager import DatasetManager
from ..modules.visualization import VisualizationManager
from ..interfaces.trainer import ITrainer
from .trainer_wrapper import TransformersTrainerWrapper

if TYPE_CHECKING:
    from transformers import Trainer, TrainingArguments



logger = logging.getLogger(__name__)

class NixOSBaseTrainer(ITrainer):
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
        
        # Remove our custom args from kwargs before passing to parent
        custom_args = [
            'model_name', 'dataset_manager', 'visualizer', 
            'training', 'hyperparameters', 'resource_limits'
        ]
        trainer_kwargs = {k: v for k, v in kwargs.items() if k not in custom_args}
        
        # Initialize base Trainer
        trainer = Trainer(
            model=model,
            args=self.training_args,
            train_dataset=train_dataset,
            eval_dataset=eval_dataset,
            tokenizer=tokenizer,
            **trainer_kwargs
        )

        # Wrap the trainer
        self.trainer = TransformersTrainerWrapper(trainer)

        # Initialize state values needed for resuming training
        if hasattr(self.trainer.trainer, 'state') and getattr(self.trainer.trainer.state, 'train_batch_size', None) is None:
            if self.training_args.per_device_train_batch_size is None:
                self.training_args.per_device_train_batch_size = 1
            if hasattr(self.trainer.trainer, 'state'):
                self.trainer.trainer.state.train_batch_size = self.training_args.per_device_train_batch_size * max(1, self.training_args.n_gpu)
            
    def setup_training_args(self, **kwargs) -> None:
        """Set up training arguments."""
        # Default training arguments
        default_args = {
            'output_dir': self.output_dir,
            'evaluation_strategy': 'epoch',
            'save_strategy': 'steps',
            'save_steps': 100,
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
            
            # Check if we should resume from checkpoint
            if resume_from_checkpoint is None:
                resume_from_checkpoint = bool(get_last_checkpoint(self.output_dir))
            
            # Load trainer state if resuming from checkpoint
            # Check if we should resume from checkpoint
            if resume_from_checkpoint is None:
                resume_from_checkpoint = bool(get_last_checkpoint(self.output_dir))
            
            # Load trainer state if resuming from checkpoint
            if resume_from_checkpoint:
                logger.info(f"Resuming from checkpoint: {resume_from_checkpoint}")
                trainer_state_path = Path(self.output_dir) / "trainer_state.json"
                if trainer_state_path.exists():
                    try:
                        self.trainer.trainer.state.load_from_json(trainer_state_path)
                    except Exception as e:
                        logger.warning(f"Failed to load trainer state from checkpoint: {e}")
                else:
                    logger.warning(f"Trainer state file not found: {trainer_state_path}")
                # Load save_steps from trainer_state.json if available
                try:
                    trainer_state = TrainerState.load_from_json(trainer_state_path)
                    self.trainer.trainer.state.save_steps = trainer_state.save_steps
                    logger.info(f"Loaded save_steps from checkpoint: {self.trainer.trainer.state.save_steps}")
                except Exception as e:
                    logger.warning(f"Failed to load save_steps from checkpoint: {e}")
                train_result = self.trainer.train(resume_from_checkpoint=True)
            else:
                # Start training
                train_result = self.trainer.train(resume_from_checkpoint=resume_from_checkpoint)
            
            logger.info("Training completed successfully")
            
        except Exception as e:
            logger.error(f"Training error: {e}")
            raise
            
    def evaluate(self, ignore_keys=None, **kwargs) -> Dict[str, float]:
        """Evaluate the model."""
        if not self.model:
            logger.error("Model not initialized")
            raise ValueError("Model not initialized")
            
        if not self.eval_dataset:
            logger.error("No evaluation dataset provided")
            raise ValueError("No evaluation dataset provided")
            
        logger.info("Starting evaluation...")
        try:
            metrics = super().evaluate(**kwargs)
            
            # Remove ignored keys if specified
            if ignore_keys:
                for key in ignore_keys:
                    metrics.pop(key, None)
                    
            return metrics
        except Exception as e:
            logger.error(f"Evaluation error: {e}")
            raise

    def save_model(self, output_dir: str, _internal_call=False):
        """Save the model."""
        logger.info(f"Saving model to {output_dir}")
        try:
            self.trainer.save_model(output_dir, _internal_call=_internal_call)
            logger.info("Model saved successfully")
        except Exception as e:
            logger.error(f"Error saving model: {e}")
            raise
