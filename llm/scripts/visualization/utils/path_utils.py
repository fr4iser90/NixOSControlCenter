"""Utility functions for path management."""
from pathlib import Path
import sys

# Add project root to Python path
ROOT_DIR = Path(__file__).parent.parent.parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

class ProjectPaths:
    """Manages project paths and directories."""
    
    ROOT_DIR = ROOT_DIR
    DATA_DIR = ROOT_DIR / "data"
    MODELS_DIR = ROOT_DIR / "models"
    METRICS_DIR = ROOT_DIR / "metrics"
    
    @classmethod
    def ensure_directories(cls):
        """Ensure all required directories exist."""
        cls.DATA_DIR.mkdir(exist_ok=True)
        cls.MODELS_DIR.mkdir(exist_ok=True)
        cls.METRICS_DIR.mkdir(exist_ok=True)
        
    @classmethod
    def get_run_dir(cls, run_id: str) -> Path:
        """Get the directory for a specific training run."""
        run_dir = cls.METRICS_DIR / f"run_{run_id}"
        run_dir.mkdir(exist_ok=True)
        return run_dir
