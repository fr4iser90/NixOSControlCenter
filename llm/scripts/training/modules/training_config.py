#!/usr/bin/env python3
"""Configuration management for model training."""
from dataclasses import dataclass, asdict
from typing import Dict, Any, Optional
import torch
import logging

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class ModelConfig:
    """Model configuration settings."""
    name: str = "facebook/opt-125m"
    dtype: torch.dtype = torch.float16 if torch.cuda.is_available() else torch.float32
    device_map: str = "auto"
    low_cpu_mem_usage: bool = True
    gradient_checkpointing: bool = True
    use_cache: bool = False

@dataclass
class LoRAConfig:
    """LoRA-specific configuration."""
    r: int = 8
    lora_alpha: int = 32
    target_modules: list = None
    lora_dropout: float = 0.05
    bias: str = "none"
    task_type: str = "CAUSAL_LM"
    
    def __post_init__(self):
        if self.target_modules is None:
            self.target_modules = ["q_proj", "v_proj"]

@dataclass
class TrainingConfig:
    """Training hyperparameters and settings."""
    learning_rate: float = 3e-4
    num_train_epochs: int = 10
    per_device_train_batch_size: int = 4
    per_device_eval_batch_size: int = 4
    gradient_accumulation_steps: int = 8
    warmup_steps: int = 100
    logging_steps: int = 10
    evaluation_strategy: str = "steps"
    eval_steps: int = 50
    save_strategy: str = "steps"
    save_steps: int = 50
    save_total_limit: int = 3
    load_best_model_at_end: bool = True
    metric_for_best_model: str = "loss"
    greater_is_better: bool = False

class ConfigManager:
    """Manages training configurations."""
    
    @staticmethod
    def get_default_config() -> Dict[str, Any]:
        """Get default training configuration."""
        return {
            'model': asdict(ModelConfig()),
            'lora': asdict(LoRAConfig()),
            'training': asdict(TrainingConfig())
        }
    
    @staticmethod
    def merge_config(base_config: Dict[str, Any], override_config: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Merge override config into base config."""
        if not override_config:
            return base_config
            
        merged = base_config.copy()
        for key, value in override_config.items():
            if key in merged and isinstance(merged[key], dict) and isinstance(value, dict):
                merged[key] = ConfigManager.merge_config(merged[key], value)
            else:
                merged[key] = value
        return merged
        
    @staticmethod
    def validate_config(config: Dict[str, Any]) -> bool:
        """Validate configuration settings."""
        try:
            # Convert dict configs to dataclass instances
            model_config = ModelConfig(**config.get('model', {}))
            lora_config = LoRAConfig(**config.get('lora', {}))
            training_config = TrainingConfig(**config.get('training', {}))
            
            # Convert back to dict for consistency
            config['model'] = asdict(model_config)
            config['lora'] = asdict(lora_config)
            config['training'] = asdict(training_config)
            
            return True
        except Exception as e:
            logger.error(f"Configuration validation failed: {e}")
            return False
