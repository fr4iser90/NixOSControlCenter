#!/usr/bin/env python3
"""Project path configuration and management."""
import sys
from pathlib import Path
import os
from typing import List, Optional, Dict, Union
import git
import logging

logger = logging.getLogger(__name__)

class ProjectPaths:
    """Manages project paths and directory structure."""
    
    # Get the project root directory
    CURRENT_DIR = Path(os.getcwd()).resolve()
    PROJECT_ROOT = CURRENT_DIR
    
    # Base directories
    LLM_DIR = PROJECT_ROOT
    
    # Data directories
    DATA_DIR = LLM_DIR / 'data'
    MODELS_DIR = LLM_DIR / 'models'
    MODEL_DIR = MODELS_DIR  # Alias for backward compatibility
    PROCESSED_DIR = DATA_DIR / 'processed'
    RAW_DIR = DATA_DIR / 'raw'
    SCRIPTS_DIR = LLM_DIR / 'scripts'
    
    # Module directories
    TRAINING_DIR = SCRIPTS_DIR / 'training'
    TRAINING_MODULES_DIR = TRAINING_DIR / 'modules'
    TRAINERS_DIR = TRAINING_DIR / 'trainers'  # Add trainers directory
    UTILS_DIR = SCRIPTS_DIR / 'utils'
    MONITORING_DIR = SCRIPTS_DIR / 'monitoring'
    MODEL_DIR = SCRIPTS_DIR / 'model'  # Add model directory
    
    # Visualization directories
    VISUALIZATION_DIR = SCRIPTS_DIR / 'visualization'
    METRICS_DIR = MODELS_DIR / 'metrics'
    
    # Dataset directories
    DATASET_DIR = PROCESSED_DIR / 'datasets'
    CONCEPTS_DIR = DATASET_DIR / 'concepts'
    TRAINING_TASKS_DIR = DATASET_DIR / 'tasks'
    EXAMPLES_DIR = DATASET_DIR / 'examples'
    TROUBLESHOOTING_DIR = DATASET_DIR / 'troubleshooting'
    OPTIMIZATION_DIR = DATASET_DIR / 'optimization'
    
    # Model specific directories
    CURRENT_MODEL_DIR = MODELS_DIR / 'nixos_model'
    BASE_MODEL_DIR = MODELS_DIR / 'base'
    BASE_MODEL_PATH = BASE_MODEL_DIR / 'opt-125m'  # Local base model for LoRA
    QUANTIZED_MODEL_DIR = MODELS_DIR / 'quantized_model'
    
    # Additional configuration and logging
    CONFIG_DIR = LLM_DIR / 'config'
    TRAINER_CONFIG_DIR = CONFIG_DIR / 'trainers'
    MODEL_CONFIG_DIR = CONFIG_DIR / 'models'
    LOGS_DIR = LLM_DIR / 'logs'
    
    @classmethod
    def setup_python_path(cls) -> None:
        """Setup Python path to include project directories."""
        if str(cls.PROJECT_ROOT) not in sys.path:
            sys.path.insert(0, str(cls.PROJECT_ROOT))
    
    @classmethod
    def ensure_directories(cls) -> None:
        """Create all required directories if they don't exist."""
        try:
            directories = [
                cls.DATA_DIR, cls.MODELS_DIR, cls.PROCESSED_DIR, cls.RAW_DIR,
                cls.SCRIPTS_DIR, cls.TRAINING_DIR, cls.TRAINING_MODULES_DIR,
                cls.TRAINERS_DIR, cls.UTILS_DIR, cls.MONITORING_DIR, cls.MODEL_DIR,
                cls.VISUALIZATION_DIR, cls.METRICS_DIR, cls.DATASET_DIR,
                cls.CONCEPTS_DIR, cls.TRAINING_TASKS_DIR, cls.EXAMPLES_DIR,
                cls.TROUBLESHOOTING_DIR, cls.OPTIMIZATION_DIR, cls.CURRENT_MODEL_DIR,
                cls.QUANTIZED_MODEL_DIR, cls.CONFIG_DIR, cls.TRAINER_CONFIG_DIR,
                cls.MODEL_CONFIG_DIR, cls.LOGS_DIR, cls.BASE_MODEL_DIR
            ]
            
            for directory in directories:
                directory.mkdir(parents=True, exist_ok=True)
                logger.debug(f"Ensured directory exists: {directory}")
                
        except Exception as e:
            logger.error(f"Error creating directories: {e}")
            raise
    
    @classmethod
    def get_model_path(cls, model_name: str, checkpoint: Optional[Union[str, Path]] = None) -> Path:
        """Get the path to a model, optionally with a specific checkpoint."""
        if checkpoint:
            return cls.MODELS_DIR / str(model_name) / str(checkpoint)
        return cls.MODELS_DIR / str(model_name)
    
    @classmethod
    def get_dataset_path(cls, dataset_name: Optional[str] = None) -> Path:
        """Get the path to a dataset."""
        if dataset_name:
            return cls.DATASET_DIR / dataset_name
        return cls.DATASET_DIR
    
    @classmethod
    def get_metrics_path(cls, model_name: str) -> Path:
        """Get the path to model metrics."""
        return cls.METRICS_DIR / model_name
    
    @classmethod
    def get_visualization_path(cls, model_name: str) -> Path:
        """Get the path for visualization data."""
        return cls.VISUALIZATION_DIR / model_name
    
    @classmethod
    def get_checkpoint_paths(cls, model_name: Optional[str] = None) -> List[Path]:
        """Get all checkpoint paths for a model or all models."""
        if model_name:
            model_dir = cls.MODELS_DIR / model_name
            if not model_dir.exists():
                return []
            return sorted([d for d in model_dir.glob('checkpoint-*') if d.is_dir()])
        else:
            if not cls.MODELS_DIR.exists():
                return []
            return sorted([d for d in cls.MODELS_DIR.glob('**/checkpoint-*') if d.is_dir()])
    
    @classmethod
    def get_model_files(cls, model_name: str) -> Dict[str, Path]:
        """Get paths to important model files."""
        model_dir = cls.MODELS_DIR / model_name
        return {
            'config': model_dir / 'config.json',
            'model': model_dir / 'pytorch_model.bin',
            'adapter': model_dir / 'adapter_model.safetensors',
            'metrics': model_dir / 'metrics.json',
            'history': model_dir / 'training_history.json'
        }