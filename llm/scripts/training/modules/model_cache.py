"""Module for caching model and tokenizer instances."""
import logging
from pathlib import Path
from typing import Dict, Tuple, Optional
from transformers import AutoTokenizer, AutoModelForCausalLM

logger = logging.getLogger(__name__)

class ModelCache:
    """Singleton cache for model and tokenizer instances."""
    
    _instance = None
    _model_cache: Dict[str, Tuple[AutoModelForCausalLM, AutoTokenizer]] = {}
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(ModelCache, cls).__new__(cls)
        return cls._instance
    
    def get_model_and_tokenizer(
        self,
        model_name: str,
        device_config: Optional[dict] = None,
        force_download: bool = False
    ) -> Tuple[AutoModelForCausalLM, AutoTokenizer]:
        """Get or create model and tokenizer instance."""
        if not force_download and model_name in self._model_cache:
            logger.info(f"Using cached model and tokenizer for {model_name}")
            return self._model_cache[model_name]
            
        logger.info(f"Loading model and tokenizer for {model_name}")
        
        # Load tokenizer
        tokenizer = AutoTokenizer.from_pretrained(
            model_name,
            trust_remote_code=True,
            force_download=force_download
        )
        tokenizer.pad_token = tokenizer.eos_token
        
        # Load model with device configuration
        if device_config is None:
            device_config = {}
            
        model = AutoModelForCausalLM.from_pretrained(
            model_name,
            trust_remote_code=True,
            force_download=force_download,
            **device_config
        )
        
        # Cache the instances
        self._model_cache[model_name] = (model, tokenizer)
        return model, tokenizer
        
    def clear_cache(self):
        """Clear the model cache."""
        self._model_cache.clear()
        logger.info("Model cache cleared")
