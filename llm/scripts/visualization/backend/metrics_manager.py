"""Backend service for managing training metrics and data."""
import json
import pandas as pd
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

from ..utils.path_utils import ProjectPaths

class MetricsManager:
    """Manages the collection, storage, and retrieval of training metrics."""
    
    def __init__(self):
        self.metrics_dir = ProjectPaths.METRICS_DIR
        self.metrics_dir.mkdir(exist_ok=True)
        
    def save_training_metrics(self, step: int, metrics: Dict):
        """Save training metrics to file."""
        metrics_file = self.metrics_dir / "training_metrics.jsonl"
        metrics["step"] = step
        metrics["timestamp"] = datetime.now().isoformat()
        
        with open(metrics_file, "a") as f:
            f.write(json.dumps(metrics) + "\n")
            
    def load_training_metrics(self) -> pd.DataFrame:
        """Load training metrics from file."""
        metrics_file = self.metrics_dir / "training_metrics.jsonl"
        if not metrics_file.exists():
            return pd.DataFrame()
            
        metrics = []
        with open(metrics_file) as f:
            for line in f:
                metrics.append(json.loads(line))
        return pd.DataFrame(metrics)
        
    def get_training_runs(self) -> List[Dict]:
        """Get all training runs with their metrics."""
        runs = []
        for run_dir in self.metrics_dir.glob('run_*'):
            if run_dir.is_dir():
                run_metrics = self._load_run_metrics(run_dir)
                if run_metrics:
                    runs.append(run_metrics)
        return runs
        
    def _load_run_metrics(self, run_dir: Path) -> Optional[Dict]:
        """Load metrics for a specific training run."""
        metrics_file = run_dir / 'training_metrics.jsonl'
        if not metrics_file.exists():
            return None
            
        metrics = {
            'run_id': run_dir.name,
            'start_time': None,
            'end_time': None,
            'best_loss': float('inf'),
            'steps': [],
            'loss': [],
            'learning_rate': []
        }
        
        try:
            with open(metrics_file) as f:
                for line in f:
                    data = json.loads(line)
                    if metrics['start_time'] is None:
                        metrics['start_time'] = data['timestamp']
                    metrics['end_time'] = data['timestamp']
                    
                    if data.get('loss', float('inf')) < metrics['best_loss']:
                        metrics['best_loss'] = data['loss']
                        
                    metrics['steps'].append(data['step'])
                    metrics['loss'].append(data.get('loss', 0))
                    metrics['learning_rate'].append(data.get('learning_rate', 0))
            
            return metrics
        except Exception:
            return None
