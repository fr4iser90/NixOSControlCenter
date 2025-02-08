#!/usr/bin/env python3
"""Trainer specifically for LoRA-based model fine-tuning."""
import torch
import logging
from .feedback_trainer import FeedbackTrainer
from ..modules.model_management import ModelInitializer
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import LoraConfig, get_peft_model

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class LoRATrainer(FeedbackTrainer):
    """LoRA-specific trainer implementation."""
    
    def __init__(self, model_name: str, paths_config, lora_config=None, *args, **kwargs):
        """Initialize LoRA trainer with model and tokenizer setup.
        
        Args:
            model_name: Name or path of the model to load
            paths_config: Configuration for model paths
            lora_config: Optional LoRA configuration
            *args: Additional positional arguments
            **kwargs: Additional keyword arguments
        """
        logger.info(f"Initializing LoRA trainer for model: {model_name}")
        
        # Setup model and tokenizer first
        self.model_name = model_name
        self.lora_config = lora_config or {}
        
        # Initialize model manager
        model_manager = ModelInitializer(paths_config)
        
        # Get model and tokenizer from manager
        device_config = {
            'device_map': 'auto',
            'torch_dtype': torch.float16,
            'weights_only': True,  # Prevent arbitrary code execution during loading
        }
        self.model, self.tokenizer = model_manager.initialize_model(model_name, device_config)
        
        # Apply LoRA config
        config = LoraConfig(
            r=self.lora_config.get('r', 8),
            lora_alpha=self.lora_config.get('lora_alpha', 16),
            target_modules=self.lora_config.get('target_modules', ['q_proj', 'v_proj']),
            lora_dropout=self.lora_config.get('lora_dropout', 0.05),
            bias=self.lora_config.get('bias', 'none'),
            task_type="CAUSAL_LM"
        )
        self.model = get_peft_model(self.model, config)
        
        # Remove model and tokenizer from kwargs to avoid duplicates
        kwargs.pop('model', None)
        kwargs.pop('tokenizer', None)
        
        # Initialize parent class
        super().__init__(
            model_name=model_name,
            model=self.model,
            tokenizer=self.tokenizer,
            *args,
            **kwargs
        )
        
    def load_model(self, model_path: str):
        """Load a saved model and tokenizer."""
        try:
            # Initialize model manager
            model_manager = ModelInitializer(self.paths_config)
            
            # Load model and tokenizer from manager
            device_config = {
                'device_map': 'auto',
                'torch_dtype': torch.float16,
                'weights_only': True,  # Prevent arbitrary code execution during loading
            }
            self.model, self.tokenizer = model_manager.initialize_model(model_path, device_config)
            
            # Apply LoRA config
            config = LoraConfig(
                r=self.lora_config.get('r', 8),
                lora_alpha=self.lora_config.get('lora_alpha', 16),
                target_modules=self.lora_config.get('target_modules', ['q_proj', 'v_proj']),
                lora_dropout=self.lora_config.get('lora_dropout', 0.05),
                bias=self.lora_config.get('bias', 'none'),
                task_type="CAUSAL_LM"
            )
            self.model = get_peft_model(self.model, config)
            
            # Move to GPU if available
            if torch.cuda.is_available():
                self.model = self.model.to("cuda")
                
            logger.info(f"Model loaded from {model_path}")
        except Exception as e:
            logger.error(f"Error loading model: {e}")
            raise
            
    def save_pretrained(self, output_dir):
        """Save LoRA weights and tokenizer."""
        self.model.save_pretrained(output_dir)
        if hasattr(self, 'processing_class'):
            self.processing_class.save_pretrained(output_dir)
        elif hasattr(self, 'tokenizer'):
            self.tokenizer.save_pretrained(output_dir)
