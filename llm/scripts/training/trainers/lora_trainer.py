#!/usr/bin/env python3
"""Trainer specifically for LoRA-based model fine-tuning."""
import torch
import logging
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import LoraConfig, get_peft_model
from .feedback_trainer import FeedbackTrainer

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class LoRATrainer(FeedbackTrainer):
    """LoRA-specific trainer implementation."""
    
    def __init__(self, model_name: str, lora_config=None, *args, **kwargs):
        """Initialize LoRA trainer with model and tokenizer setup.
        
        Args:
            model_name: Name or path of the model to load
            lora_config: Optional LoRA configuration
            *args: Additional positional arguments
            **kwargs: Additional keyword arguments
        """
        logger.info(f"Initializing LoRA trainer for model: {model_name}")
        
        # Setup model and tokenizer first
        self.model_name = model_name
        self.lora_config = lora_config or {}
        
        # Load model and tokenizer
        self.tokenizer = AutoTokenizer.from_pretrained(
            model_name,
            trust_remote_code=True,
            force_download=True
        )
        self.model = AutoModelForCausalLM.from_pretrained(
            model_name,
            device_map='auto',
            torch_dtype=torch.float16,
            trust_remote_code=True,
            force_download=True
        )
        
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
        
    def setup_model(self):
        """Initialize the model with LoRA configuration."""
        try:
            logger.info("Setting up tokenizer...")
            
            # Load tokenizer first
            self.tokenizer = AutoTokenizer.from_pretrained(
                self.model_name,
                padding_side="left",
                trust_remote_code=True,
                force_download=True
            )
            self.tokenizer.pad_token = self.tokenizer.eos_token
            
            # Load base model and tokenizer
            base_model = AutoModelForCausalLM.from_pretrained(
                self.model_name,
                torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
                device_map="auto",
                low_cpu_mem_usage=True,
                trust_remote_code=True,
                force_download=True
            )
            base_model.config.pad_token_id = self.tokenizer.eos_token_id
            base_model.config.use_cache = False  # Required for gradient checkpointing
            
            # Enable gradient checkpointing
            base_model.gradient_checkpointing_enable()
            
            # Configure LoRA
            lora_config = LoraConfig(
                r=16,  # rank
                lora_alpha=32,
                target_modules=["q_proj", "v_proj"],
                lora_dropout=0.05,
                bias="none",
                task_type="CAUSAL_LM"
            )
            
            # Create PEFT model
            self.model = get_peft_model(base_model, lora_config)
            
            # Move to GPU if available
            if torch.cuda.is_available():
                self.model = self.model.to("cuda")
                torch.backends.cuda.enable_flash_sdp(True)
                torch.backends.cuda.enable_mem_efficient_sdp(True)
                
            logger.info("Model setup complete")
            
        except Exception as e:
            logger.error(f"Error setting up model: {e}")
            raise

    def save_pretrained(self, output_dir):
        """Save LoRA weights and tokenizer."""
        self.model.save_pretrained(output_dir)
        if hasattr(self, 'processing_class'):
            self.processing_class.save_pretrained(output_dir)
        elif hasattr(self, 'tokenizer'):
            self.tokenizer.save_pretrained(output_dir)
