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
        eval_dataset: Optional[Dataset] = None
    ) -> NixOSBaseTrainer:
        """Create a trainer instance based on type.
        
        Args:
            trainer_type: Type of trainer to create ('lora' or 'feedback')
            model_path: Path to model or model name
            config: Optional configuration dictionary
            dataset_manager: Optional dataset manager instance
            visualizer: Optional visualization manager instance
            train_dataset: Optional training dataset
            eval_dataset: Optional evaluation dataset
            
        Returns:
            Trainer instance
        """
        try:
            logger.info(f"Creating {trainer_type} trainer for model: {model_path}")
            
            # Extract LoRA specific config if present
            lora_config = config.get('lora', {}) if config else {}
            
            # Prepare trainer configuration
            trainer_config = {
                'model_name': str(model_path),
                'dataset_manager': dataset_manager,
                'visualizer': visualizer,
                'train_dataset': train_dataset,
                'eval_dataset': eval_dataset,
                'output_dir': config.get('output_dir') if config else None,
                'lora_config': lora_config
            }
            
            # Add training configuration if provided
            if config:
                # Filter out special config sections
                training_config = {
                    k: v for k, v in config.items()
                    if k not in ['lora', 'output_dir'] and k not in trainer_config
                }
                trainer_config.update(training_config)
            
            # Create trainer based on type
            if trainer_type == 'lora':
                trainer = LoRATrainer(**trainer_config)
            elif trainer_type == 'feedback':
                trainer = FeedbackTrainer(**trainer_config)
            else:
                raise ValueError(f"Unknown trainer type: {trainer_type}")
                
            return trainer
            
        except Exception as e:
            logger.error(f"Failed to create trainer: {e}")
            raise
        
    @classmethod
    def get_available_trainer_types(cls) -> List[str]:
        """Get list of available trainer types."""
        return list(cls.TRAINER_TYPES.keys())
