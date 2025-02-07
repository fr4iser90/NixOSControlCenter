#!/usr/bin/env python3
"""Module for managing model information and metadata."""
import logging
from pathlib import Path
from typing import Dict, List, Any, Optional

from ..utils.path_config import ProjectPaths

logger = logging.getLogger(__name__)

class ModelInfo:
    """Handles model information, history, and metadata."""
    
    def __init__(self, models_dir: Path):
        """Initialize with models directory."""
        self.models_dir = models_dir
        
    def get_model_overview(self, model_name: str) -> Dict[str, Any]:
        """Get comprehensive model overview including history and metrics."""
        model_dir = self.models_dir / model_name
        overview = {
            'name': model_name,
            'history': self._load_training_history(model_name),
            'architecture': self._get_model_architecture(model_name),
            'performance': self._get_performance_metrics(model_name),
            'checkpoints': self.list_checkpoints(model_name),
            'datasets': self._get_datasets_used(model_name)
        }
        return overview
        
    def list_checkpoints(self, model_name: Optional[str] = None) -> List[Path]:
        """List all available checkpoints for a model."""
        if model_name:
            model_dir = self.models_dir / model_name
            if not model_dir.exists():
                return []
            return sorted([d for d in model_dir.glob('checkpoint-*') if d.is_dir()])
        else:
            if not self.models_dir.exists():
                return []
            return sorted([d for d in self.models_dir.glob('**/checkpoint-*') if d.is_dir()])
            
    def get_model_info(self) -> Dict[str, Any]:
        """Get detailed information about available models and checkpoints."""
        available_models = {}
        
        for model_dir in self.models_dir.iterdir():
            if model_dir.is_dir() and model_dir.name not in ['metrics', 'quantized_model']:
                has_model = (
                    ((model_dir / 'adapter_config.json').exists() and
                     (model_dir / 'adapter_model.safetensors').exists()) or
                    ((model_dir / 'config.json').exists() and
                     any(model_dir.glob('pytorch_model*.bin')))
                )
                if has_model:
                    available_models[model_dir.name] = {
                        'path': model_dir,
                        'overview': self.get_model_overview(model_dir.name),
                        'checkpoints': self.list_checkpoints(model_dir.name)
                    }
        
        return {
            'available_models': available_models,
            'has_quantized': (self.models_dir / 'quantized_model').exists(),
            'total_checkpoints': len(self.list_checkpoints())
        }
        
    def get_available_models(self) -> List[str]:
        """Get list of available trained models."""
        if not self.models_dir.exists():
            self.models_dir.mkdir(parents=True, exist_ok=True)
            
        # Only include directories that contain model files
        models = []
        for d in self.models_dir.iterdir():
            if not d.is_dir() or d.name == 'monitoring':  # Exclude monitoring directory
                continue
            # Check if directory contains model files
            if (d / 'adapter_model.safetensors').exists() or (d / 'pytorch_model.bin').exists():
                models.append(d.name)
        return models
        
    def _load_training_history(self, model_name: str) -> List[Dict]:
        """Load training history for a model."""
        history_file = self.models_dir / model_name / 'training_history.json'
        if not history_file.exists():
            return []
        with open(history_file, 'r') as f:
            return json.load(f)
            
    def _get_model_architecture(self, model_name: str) -> Dict[str, Any]:
        """Get model architecture information."""
        config_file = self.models_dir / model_name / 'config.json'
        if not config_file.exists():
            return {}
        with open(config_file, 'r') as f:
            return json.load(f)
            
    def _get_performance_metrics(self, model_name: str) -> Dict[str, Any]:
        """Get model performance metrics."""
        metrics_file = self.models_dir / model_name / 'metrics.json'
        if not metrics_file.exists():
            return {}
        with open(metrics_file, 'r') as f:
            return json.load(f)
            
    def _get_datasets_used(self, model_name: str) -> List[str]:
        """Get list of datasets used in training."""
        history = self._load_training_history(model_name)
        datasets = set()
        for entry in history:
            if 'dataset' in entry:
                datasets.add(entry['dataset'])
        return list(datasets)
