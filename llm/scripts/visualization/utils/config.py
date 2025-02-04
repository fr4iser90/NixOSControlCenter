"""Configuration management for visualization components."""
from typing import Dict, Any
import json
from pathlib import Path

class VisualizerConfig:
    """Manages configuration for the visualization dashboard."""
    
    DEFAULT_CONFIG = {
        'auto_refresh': True,
        'refresh_interval': 5,
        'plot_height': 800,
        'max_points': 10000,
        'theme': 'dark',
        'sidebar_state': 'expanded'
    }
    
    def __init__(self, config_path: Path = None):
        self.config_path = config_path or Path(__file__).parent.parent / 'config.json'
        self.config = self._load_config()
        
    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from file or use defaults."""
        if self.config_path.exists():
            try:
                with open(self.config_path) as f:
                    return {**self.DEFAULT_CONFIG, **json.load(f)}
            except Exception:
                return self.DEFAULT_CONFIG
        return self.DEFAULT_CONFIG
        
    def save_config(self):
        """Save current configuration to file."""
        with open(self.config_path, 'w') as f:
            json.dump(self.config, f, indent=4)
            
    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value."""
        return self.config.get(key, default)
        
    def set(self, key: str, value: Any):
        """Set configuration value."""
        self.config[key] = value
        self.save_config()
        
    def update(self, updates: Dict[str, Any]):
        """Update multiple configuration values."""
        self.config.update(updates)
        self.save_config()
