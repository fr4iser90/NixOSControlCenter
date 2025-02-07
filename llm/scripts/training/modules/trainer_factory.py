#!/usr/bin/env python3
"""Factory for creating model trainers."""
import logging
from typing import Dict, Any, Optional, Type
from pathlib import Path

from ..trainers.base_trainer import NixOSBaseTrainer
from ..trainers.lora_trainer import LoRATrainer
from ..trainers.feedback_trainer import FeedbackTrainer
from .training_config import ConfigManager

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
        dataset_manager = None,
        visualizer = None,
        **kwargs
    ) -> NixOSBaseTrainer:
        """Create and configure a trainer instance.
        
        Args:
            trainer_type: Type of trainer to create ('base', 'lora', or 'feedback')
            model_path: Path to model or model identifier
            config: Optional configuration override
            dataset_manager: Optional dataset manager instance
            visualizer: Optional visualization manager instance
            **kwargs: Additional trainer arguments
            
        Returns:
            Configured trainer instance
        """
        # Get trainer class
        trainer_class = cls.TRAINER_TYPES.get(trainer_type)
        if not trainer_class:
            raise ValueError(f"Unknown trainer type: {trainer_type}")
            
        # Get and merge configuration
        base_config = ConfigManager.get_default_config()
        if config:
            base_config = ConfigManager.merge_config(base_config, config)
            
        # Validate configuration
        if not ConfigManager.validate_config(base_config):
            raise ValueError("Invalid configuration")
            
        # Create trainer
        trainer_kwargs = {
            'model_name': str(model_path),
            'dataset_manager': dataset_manager,
            'visualizer': visualizer,
            **kwargs
        }
        
        # Add configuration-specific arguments
        if trainer_type == 'lora':
            trainer_kwargs['lora_config'] = base_config['lora']
            
        return trainer_class(**trainer_kwargs)
        
    @classmethod
    def get_available_trainer_types(cls) -> List[str]:
        """Get list of available trainer types."""
        return list(cls.TRAINER_TYPES.keys())
