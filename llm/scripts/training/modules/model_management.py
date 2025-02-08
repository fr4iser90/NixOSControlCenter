"""Module for managing model initialization and configuration."""
import torch
from pathlib import Path
from transformers import AutoTokenizer, AutoModelForCausalLM
from peft import LoraConfig, get_peft_model
import logging

logger = logging.getLogger(__name__)

class ModelInitializer:
    """Handles model initialization and configuration."""
    
    _base_model = None
    _base_tokenizer = None
    
    def __init__(self, paths_config):
        """Initialize with project paths configuration."""
        self.paths_config = paths_config
        
    def initialize_model(self, model_name: str, device_config: dict = None):
        """Initialize model based on whether it's new or existing."""
        if device_config is None:
            device_config = {
                'torch_dtype': torch.float16 if torch.cuda.is_available() else torch.float32,
                'device_map': "auto",
                'low_cpu_mem_usage': True
            }
            
        model_path = Path(model_name)
        if model_path.exists():
            # Check for adapter files or full model files
            has_model = (
                (model_path / "adapter_config.json").exists() or
                (model_path / "config.json").exists()
            )
            if has_model:
                logger.info(f"Found existing model at {model_path}")
                return self.load_existing_model(model_path, device_config)
                
        logger.info("No existing model found, creating new one...")
        return self.create_new_model(device_config)
            
    def load_existing_model(self, model_path: Path, device_config: dict):
        """Load an existing model and its tokenizer."""
        logger.info(f"Loading existing model from {model_path}...")
        
        # Check if we have adapter files
        if (model_path / "adapter_config.json").exists():
            # Load or reuse base model
            base_model = self._get_or_create_base_model(device_config)
            tokenizer = self._get_or_create_tokenizer()
            
            # Apply LoRA config and load adapter
            lora_config = self.setup_lora_config()
            model = get_peft_model(base_model, lora_config)
            model.load_adapter(model_path, adapter_name="default")
            logger.info("Loaded existing LoRA weights")
        else:
            # Load full model
            model = AutoModelForCausalLM.from_pretrained(
                model_path,
                trust_remote_code=True,
                force_download=True,
                **device_config
            )
            tokenizer = self._get_or_create_tokenizer()
            logger.info("Loaded full model weights")
            
        return model, tokenizer
        
    def create_new_model(self, device_config: dict):
        """Create a new model instance."""
        logger.info("Creating new NixOS model based on facebook/opt-125m...")
        
        # Get or create base model and tokenizer
        base_model = self._get_or_create_base_model(device_config)
        tokenizer = self._get_or_create_tokenizer()
        
        # Apply LoRA configuration
        lora_config = self.setup_lora_config()
        model = get_peft_model(base_model, lora_config)
        model.print_trainable_parameters()
        
        return model, tokenizer
        
    def _get_or_create_base_model(self, device_config: dict):
        """Get existing base model or create new one."""
        if self._base_model is None:
            logger.info("Loading base model...")
            self._base_model = AutoModelForCausalLM.from_pretrained(
                "facebook/opt-125m",
                trust_remote_code=True,
                force_download=True,
                **device_config
            )
            self._base_model.config.pad_token_id = self._base_model.config.eos_token_id
            self._base_model.config.use_cache = False
            self._base_model.gradient_checkpointing_enable()
            
        return self._base_model
        
    def _get_or_create_tokenizer(self):
        """Get existing tokenizer or create new one."""
        if self._base_tokenizer is None:
            logger.info("Loading tokenizer...")
            self._base_tokenizer = AutoTokenizer.from_pretrained(
                "facebook/opt-125m",
                padding_side="left",
                trust_remote_code=True,
                force_download=True
            )
            self._base_tokenizer.pad_token = self._base_tokenizer.eos_token
            
        return self._base_tokenizer
        
    @staticmethod
    def setup_lora_config():
        """Create LoRA configuration."""
        return LoraConfig(
            r=8,
            lora_alpha=32,
            target_modules=["q_proj", "v_proj"],
            lora_dropout=0.05,
            bias="none",
            task_type="CAUSAL_LM"
        )
        
    def move_to_device(self, model):
        """Move model to appropriate device and enable optimizations."""
        if torch.cuda.is_available():
            model = model.to("cuda")
            torch.backends.cuda.enable_flash_sdp(True)
            torch.backends.cuda.enable_mem_efficient_sdp(True)
        return model
