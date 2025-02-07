#!/usr/bin/env python3
"""Factory for creating model trainers."""
import logging
from typing import Dict, Any, Optional, Type, Union, List
from pathlib import Path
from datasets import Dataset

from ...utils.path_config import ProjectPaths
from ..trainers.base_trainer import NixOSBaseTrainer
from ..trainers.lora_trainer import LoRATrainer
from ..trainers.feedback_trainer import FeedbackTrainer
from ...data.dataset_manager import DatasetManager
from .visualization import VisualizationManager
from .training_config import ConfigManager

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class TrainerFactory:
    """Factory for creating and configuring trainers."""
    
    TRAINER_TYPES = {
        'base': NixOSBaseTrainer,
        'lora': LoRATrainer,
        'feedback': FeedbackTrainer
    }
    
    @classmethod
    def create_trainer(
        cls,
        trainer_type: str,
        model_path: Union[str, Path],
        config: Optional[Dict[str, Any]] = None,
        dataset_manager: Optional[DatasetManager] = None,
        visualizer: Optional[VisualizationManager] = None,
        train_dataset: Optional[Dataset] = None,
        eval_dataset: Optional[Dataset] = None,
        **kwargs
    ) -> NixOSBaseTrainer:
        """Create and configure a trainer instance.
        
        Args:
            trainer_type: Type of trainer to create ('base', 'lora', or 'feedback')
            model_path: Path to model or model identifier
            config: Optional configuration override
            dataset_manager: Optional dataset manager instance
            visualizer: Optional visualization manager instance
            train_dataset: Optional training dataset
            eval_dataset: Optional evaluation dataset
            **kwargs: Additional trainer arguments
            
        Returns:
            Configured trainer instance
            
        Raises:
            ValueError: If trainer_type is unknown or configuration is invalid
            Exception: If trainer initialization fails
        """
        try:
            # Get trainer class
            trainer_class = cls.TRAINER_TYPES.get(trainer_type)
            if not trainer_class:
                logger.error(f"Unknown trainer type: {trainer_type}")
                raise ValueError(f"Unknown trainer type: {trainer_type}")
                
            # Get and merge configuration
            base_config = ConfigManager.get_default_config()
            if config:
                base_config = ConfigManager.merge_config(base_config, config)
                
            # Validate configuration
            if not ConfigManager.validate_config(base_config):
                logger.error("Invalid configuration")
                raise ValueError("Invalid configuration")
                
            # Create trainer
            trainer_kwargs = {
                'model_name': str(model_path),
                'dataset_manager': dataset_manager,
                'visualizer': visualizer,
                'train_dataset': train_dataset,
                'eval_dataset': eval_dataset,
                **kwargs
            }
            
            # Add configuration-specific arguments
            if trainer_type == 'lora':
                trainer_kwargs['lora_config'] = base_config['lora']
                
            logger.info(f"Creating {trainer_type} trainer for model: {model_path}")
            return trainer_class(**trainer_kwargs)
            
        except Exception as e:
            logger.error(f"Failed to create trainer: {str(e)}")
            raise
        
    @classmethod
    def get_available_trainer_types(cls) -> List[str]:
        """Get list of available trainer types."""
        return list(cls.TRAINER_TYPES.keys())
