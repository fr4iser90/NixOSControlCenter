"""Module for managing base models and their configurations."""
import json
import logging
from pathlib import Path
from typing import Dict, List, Optional
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from huggingface_hub import HfApi, ModelFilter

logger = logging.getLogger(__name__)

class BaseModelManager:
    """Manager for base models, handling downloads, caching, and configuration."""
    
    # Default base model
    DEFAULT_BASE_MODEL = "facebook/opt-125m"
    
    def __init__(self, paths_config):
        """Initialize base model manager.
        
        Args:
            paths_config: Project paths configuration
        """
        self.paths_config = paths_config
        self.base_models_dir = Path(paths_config.BASE_MODELS_DIR)
        self.base_models_dir.mkdir(parents=True, exist_ok=True)
        self.config_file = self.base_models_dir / "base_models_config.json"
        self.model_configs = self._load_configs()
        
    def _load_configs(self) -> Dict:
        """Load existing base model configurations."""
        if self.config_file.exists():
            with open(self.config_file, 'r') as f:
                return json.load(f)
        return {
            "models": {
                self.DEFAULT_BASE_MODEL: {
                    "name": self.DEFAULT_BASE_MODEL,
                    "description": "Default base model (OPT-125M)",
                    "parameters": "125M",
                    "local_path": str(self.base_models_dir / "opt-125m"),
                    "downloaded": False
                }
            },
            "active_model": self.DEFAULT_BASE_MODEL
        }
        
    def _save_configs(self):
        """Save current base model configurations."""
        with open(self.config_file, 'w') as f:
            json.dump(self.model_configs, f, indent=2)
            
    def get_active_model_name(self) -> str:
        """Get currently active base model name."""
        return self.model_configs["active_model"]
        
    def set_active_model(self, model_name: str):
        """Set active base model.
        
        Args:
            model_name: Name of model to set as active
        """
        if model_name not in self.model_configs["models"]:
            raise ValueError(f"Model {model_name} not found in configurations")
            
        self.model_configs["active_model"] = model_name
        self._save_configs()
        logger.info(f"Set active base model to: {model_name}")
        
    def search_models(self, query: str = "", task_type: str = "text-generation", 
                     min_likes: int = 50) -> List[Dict]:
        """Search for available base models on HuggingFace Hub.
        
        Args:
            query: Search query
            task_type: Type of model to search for
            min_likes: Minimum number of likes to filter models
            
        Returns:
            List of matching models with metadata
        """
        api = HfApi()
        
        # Create model filter
        model_filter = ModelFilter(
            task=task_type,
            min_likes=min_likes,
            model_name=query if query else None
        )
        
        # Search models
        models = api.list_models(filter=model_filter, limit=20)
        
        # Format results
        results = []
        for model in models:
            results.append({
                "name": model.modelId,
                "description": model.description,
                "likes": model.likes,
                "downloads": model.downloads,
                "tags": model.tags,
                "pipeline_tag": model.pipeline_tag
            })
            
        return results
        
    def download_model(self, model_name: str, force: bool = False) -> bool:
        """Download and cache a base model.
        
        Args:
            model_name: Name/ID of model to download
            force: Force re-download even if already exists
            
        Returns:
            True if successful, False otherwise
        """
        try:
            # Create model directory
            model_dir = self.base_models_dir / model_name.split("/")[-1]
            if model_dir.exists() and not force:
                logger.info(f"Model {model_name} already downloaded")
                return True
                
            # Download model and tokenizer
            logger.info(f"Downloading model {model_name}...")
            model = AutoModelForCausalLM.from_pretrained(
                model_name,
                trust_remote_code=True,
                torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
                low_cpu_mem_usage=True
            )
            tokenizer = AutoTokenizer.from_pretrained(
                model_name,
                trust_remote_code=True
            )
            
            # Save locally
            model.save_pretrained(model_dir)
            tokenizer.save_pretrained(model_dir)
            
            # Update configs
            self.model_configs["models"][model_name] = {
                "name": model_name,
                "description": "Downloaded base model",
                "local_path": str(model_dir),
                "downloaded": True
            }
            self._save_configs()
            
            logger.info(f"Successfully downloaded model {model_name}")
            return True
            
        except Exception as e:
            logger.error(f"Error downloading model {model_name}: {e}")
            return False
            
    def load_model(self, model_name: Optional[str] = None, device_config: Optional[Dict] = None) -> tuple:
        """Load a base model and tokenizer.
        
        Args:
            model_name: Name of model to load, uses active model if None
            device_config: Optional device configuration
            
        Returns:
            Tuple of (model, tokenizer)
        """
        if model_name is None:
            model_name = self.get_active_model_name()
            
        if model_name not in self.model_configs["models"]:
            raise ValueError(f"Model {model_name} not found in configurations")
            
        model_config = self.model_configs["models"][model_name]
        if not model_config["downloaded"]:
            if not self.download_model(model_name):
                raise RuntimeError(f"Failed to download model {model_name}")
                
        # Set default device config if none provided
        if device_config is None:
            device_config = {
                'torch_dtype': torch.float16 if torch.cuda.is_available() else torch.float32,
                'device_map': "auto",
                'low_cpu_mem_usage': True
            }
            
        # Load model and tokenizer
        model = AutoModelForCausalLM.from_pretrained(
            model_config["local_path"],
            trust_remote_code=True,
            **device_config
        )
        tokenizer = AutoTokenizer.from_pretrained(
            model_config["local_path"],
            trust_remote_code=True
        )
        
        return model, tokenizer
        
    def list_downloaded_models(self) -> List[Dict]:
        """List all downloaded base models.
        
        Returns:
            List of model configurations
        """
        return [
            config for config in self.model_configs["models"].values()
            if config["downloaded"]
        ]
