from pathlib import Path
import os
from typing import List, Optional

class ProjectPaths:
    # Get the project root directory (parent of the llm directory)
    CURRENT_DIR = Path(__file__).resolve().parent
    PROJECT_ROOT = Path(os.getenv('PROJECT_ROOT', CURRENT_DIR.parent.parent.parent))
    
    # Base directories - no need to append 'llm' since we're already in it
    LLM_DIR = PROJECT_ROOT
    
    # Data directories
    DATA_DIR = LLM_DIR / 'data'
    MODELS_DIR = LLM_DIR / 'models'
    MODEL_DIR = MODELS_DIR  # Alias for backward compatibility
    PROCESSED_DIR = DATA_DIR / 'processed'
    RAW_DIR = DATA_DIR / 'raw'
    SCRIPTS_DIR = LLM_DIR / 'scripts'
    
    # Visualization directories
    VISUALIZATION_DIR = SCRIPTS_DIR / 'visualization'
    METRICS_DIR = MODELS_DIR / 'metrics'  # For storing training metrics and visualization data
    
    # Dataset directories
    DATASET_DIR = PROCESSED_DIR / 'datasets'
    CONCEPTS_DIR = DATASET_DIR / 'concepts'
    TRAINING_TASKS_DIR = DATASET_DIR / 'tasks'
    EXAMPLES_DIR = DATASET_DIR / 'examples'
    TROUBLESHOOTING_DIR = DATASET_DIR / 'troubleshooting'
    OPTIMIZATION_DIR = DATASET_DIR / 'optimization'
    
    # Model specific directories
    CURRENT_MODEL_DIR = MODELS_DIR / 'nixos_model'
    QUANTIZED_MODEL_DIR = MODELS_DIR / 'quantized_model'
    
    # Dataset files by category
    # Concepts
    BASIC_CONCEPTS = CONCEPTS_DIR / 'nixos_concepts.jsonl'
    ADVANCED_CONCEPTS = CONCEPTS_DIR / 'nixos_advanced_concepts.jsonl'
    
    # Training tasks
    TRAINING_TASKS = TRAINING_TASKS_DIR / 'nixos_training_tasks.jsonl'
    
    # Examples
    PRACTICAL_EXAMPLES = EXAMPLES_DIR / 'nixos_practical_examples.jsonl'
    
    # Troubleshooting
    TROUBLESHOOTING = TROUBLESHOOTING_DIR / 'nixos_troubleshooting.jsonl'
    
    # Raw datasets (original data)
    FLAKE_DATASET = RAW_DIR / 'flake_datasets.jsonl'
    HOME_MANAGER_DATASET = RAW_DIR / 'home_manager_datasets.jsonl'
    NIX_DATASET = RAW_DIR / 'nix_datasets.jsonl'
    NIXOS_DATASET = RAW_DIR / 'nixos_datasets.jsonl'
    NIXPKGS_DATASET = RAW_DIR / 'nixpkgs_datasets.jsonl'
    WHAT_IS_NIXOS_DATASET = RAW_DIR / 'what_is_nixos.jsonl'

    @classmethod
    def validate_paths(cls) -> List[str]:
        """Validate critical paths and return list of missing paths"""
        missing = []
        critical_paths = [
            (cls.PROJECT_ROOT, "Project root directory"),
            (cls.LLM_DIR, "LLM directory"),
            (cls.DATA_DIR, "Data directory"),
        ]
        
        for path, desc in critical_paths:
            if not path.exists():
                missing.append(f"{desc} not found at: {path}")
        
        return missing

    @classmethod
    def get_checkpoint_pattern(cls) -> Path:
        """Get pattern for checkpoint directories"""
        return cls.MODELS_DIR / 'checkpoint-*'

    @classmethod
    def get_optimization_pattern(cls) -> Path:
        """Pattern to match optimization dataset files"""
        return cls.OPTIMIZATION_DIR / 'nixos_optimization_dataset_*.json'

    @classmethod
    def ensure_directories(cls) -> None:
        """Create all necessary directories if they don't exist"""
        # First validate critical paths
        missing = cls.validate_paths()
        if missing:
            raise FileNotFoundError(
                "Critical paths are missing. Please ensure the project is properly set up:\n" +
                "\n".join(missing)
            )
        
        directories = [
            cls.MODELS_DIR,
            cls.PROCESSED_DIR,
            cls.RAW_DIR,
            cls.SCRIPTS_DIR,
            cls.DATASET_DIR,
            cls.CONCEPTS_DIR,
            cls.TRAINING_TASKS_DIR,
            cls.EXAMPLES_DIR,
            cls.TROUBLESHOOTING_DIR,
            cls.OPTIMIZATION_DIR,
            cls.VISUALIZATION_DIR,
            cls.METRICS_DIR,
        ]
        
        for directory in directories:
            try:
                directory.mkdir(parents=True, exist_ok=True)
            except PermissionError:
                raise PermissionError(f"No permission to create directory: {directory}")
            except Exception as e:
                raise Exception(f"Failed to create directory {directory}: {str(e)}")
                
    @classmethod
    def get_dataset_files(cls) -> List[Path]:
        """Get all dataset files that should exist"""
        return [
            cls.BASIC_CONCEPTS,
            cls.ADVANCED_CONCEPTS,
            cls.TRAINING_TASKS,
            cls.PRACTICAL_EXAMPLES,
            cls.TROUBLESHOOTING,
            cls.FLAKE_DATASET,
            cls.HOME_MANAGER_DATASET,
            cls.NIX_DATASET,
            cls.NIXOS_DATASET,
            cls.NIXPKGS_DATASET,
            cls.WHAT_IS_NIXOS_DATASET,
        ]