"""Backend service for managing training metrics and data."""
import json
import pandas as pd
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

from scripts.utils.path_config import ProjectPaths

class MetricsManager:
    """Manages the collection, storage, and retrieval of training metrics."""
    
    def __init__(self, paths_config: ProjectPaths):
        """Initialize metrics manager.
        
        Args:
            paths_config: Project paths configuration
        """
        self.paths_config = paths_config
        self.metrics_dir = paths_config.METRICS_DIR
        self.metrics_dir.mkdir(parents=True, exist_ok=True)
        
    def save_training_metrics(self, step: int, metrics: Dict):
        """Save training metrics to file."""
        metrics_file = self.metrics_dir / "training_metrics.jsonl"
        
        # Add metadata
        metrics["step"] = step
        metrics["timestamp"] = datetime.now().isoformat()
        
        # Save metrics
        with open(metrics_file, "a") as f:
            f.write(json.dumps(metrics) + "\n")
            
    def load_training_metrics(self) -> pd.DataFrame:
        """Load training metrics from file."""
        metrics_file = self.metrics_dir / "training_metrics.jsonl"
        if not metrics_file.exists():
            return pd.DataFrame()
            
        try:
            metrics = []
            with open(metrics_file) as f:
                for line in f:
                    try:
                        metrics.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
                        
            if not metrics:
                return pd.DataFrame()
                
            df = pd.DataFrame(metrics)
            df['timestamp'] = pd.to_datetime(df['timestamp'])
            df = df.sort_values('step')
            return df
            
        except Exception as e:
            print(f"Error loading metrics: {e}")
            return pd.DataFrame()
        
    def get_training_runs(self) -> List[Dict]:
        """Get all training runs with their metrics."""
        runs = []
        for run_dir in sorted(self.metrics_dir.glob('run_*')):
            if run_dir.is_dir():
                run_metrics = self._load_run_metrics(run_dir)
                if run_metrics:
                    runs.append(run_metrics)
        return runs
        
    def _load_run_metrics(self, run_dir: Path) -> Optional[Dict]:
        """Load metrics for a specific training run."""
        try:
            metrics_file = run_dir / 'metrics.json'
            if not metrics_file.exists():
                return None
                
            with open(metrics_file) as f:
                metrics = json.load(f)
                
            # Add run metadata
            metrics['run_id'] = run_dir.name
            metrics['timestamp'] = datetime.fromtimestamp(run_dir.stat().st_mtime).isoformat()
            
            return metrics
            
        except Exception as e:
            print(f"Error loading run metrics from {run_dir}: {e}")
            return None
