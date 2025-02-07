"""Resource monitoring and alerting module."""
import logging
import psutil
import torch
import time
from pathlib import Path
import json
from typing import Dict, List, Optional
from datetime import datetime
import numpy as np
import matplotlib.pyplot as plt
from threading import Thread, Event

logger = logging.getLogger(__name__)

class ResourceMonitor:
    """Monitors system resources and model performance."""
    
    def __init__(self, output_dir: Path, alert_thresholds: Optional[Dict] = None):
        self.output_dir = output_dir
        self.monitoring_dir = output_dir / "monitoring"
        self.monitoring_dir.mkdir(parents=True, exist_ok=True)
        
        # Set default alert thresholds
        self.alert_thresholds = alert_thresholds or {
            'cpu_usage': 90.0,  # percentage
            'memory_usage': 90.0,  # percentage
            'gpu_memory': 90.0,  # percentage
            'training_loss_spike': 2.0,  # factor of moving average
            'evaluation_drop': 0.1  # absolute drop in evaluation metric
        }
        
        self.metrics_history = {
            'cpu_usage': [],
            'memory_usage': [],
            'gpu_memory': [],
            'training_loss': [],
            'evaluation_metrics': []
        }
        
        self._stop_monitoring = Event()
        self._monitor_thread = None
    
    def start_monitoring(self, interval: float = 1.0):
        """Start resource monitoring in a separate thread."""
        if self._monitor_thread is not None:
            logger.warning("Monitoring already started")
            return
        
        self._stop_monitoring.clear()
        self._monitor_thread = Thread(
            target=self._monitor_resources,
            args=(interval,),
            daemon=True
        )
        self._monitor_thread.start()
        logger.info("Resource monitoring started")
    
    def stop_monitoring(self):
        """Stop resource monitoring."""
        if self._monitor_thread is None:
            return
        
        self._stop_monitoring.set()
        self._monitor_thread.join()
        self._monitor_thread = None
        logger.info("Resource monitoring stopped")
        
        # Save final metrics
        self._save_metrics()
    
    def log_training_metric(self, metric_name: str, value: float):
        """Log a training metric."""
        self.metrics_history[metric_name].append({
            'timestamp': datetime.now().isoformat(),
            'value': value
        })
        
        # Check for anomalies
        self._check_training_anomalies(metric_name, value)
    
    def log_evaluation_metric(self, metric_name: str, value: float):
        """Log an evaluation metric."""
        self.metrics_history['evaluation_metrics'].append({
            'timestamp': datetime.now().isoformat(),
            'metric': metric_name,
            'value': value
        })
        
        # Check for performance drops
        self._check_evaluation_performance(metric_name, value)
    
    def generate_report(self) -> Dict:
        """Generate a resource usage and performance report."""
        report = {
            'resource_usage': {
                'cpu': self._calculate_stats('cpu_usage'),
                'memory': self._calculate_stats('memory_usage'),
                'gpu': self._calculate_stats('gpu_memory')
            },
            'training_metrics': {
                'loss': self._calculate_stats('training_loss')
            },
            'evaluation_metrics': self._get_latest_evaluation_metrics(),
            'alerts': self._get_recent_alerts()
        }
        
        # Generate visualizations
        self._generate_visualizations()
        
        return report
    
    def _monitor_resources(self, interval: float):
        """Monitor system resources."""
        while not self._stop_monitoring.is_set():
            try:
                # CPU usage
                cpu_percent = psutil.cpu_percent(interval=0.1)
                self.metrics_history['cpu_usage'].append({
                    'timestamp': datetime.now().isoformat(),
                    'value': cpu_percent
                })
                
                # Memory usage
                memory = psutil.virtual_memory()
                self.metrics_history['memory_usage'].append({
                    'timestamp': datetime.now().isoformat(),
                    'value': memory.percent
                })
                
                # GPU usage if available
                if torch.cuda.is_available():
                    gpu_memory_percent = (
                        torch.cuda.memory_allocated() / 
                        torch.cuda.max_memory_allocated() * 100
                        if torch.cuda.max_memory_allocated() > 0 else 0
                    )
                    self.metrics_history['gpu_memory'].append({
                        'timestamp': datetime.now().isoformat(),
                        'value': gpu_memory_percent
                    })
                
                # Check resource thresholds
                self._check_resource_thresholds()
                
                # Save metrics periodically
                self._save_metrics()
                
                time.sleep(interval)
                
            except Exception as e:
                logger.error(f"Error in resource monitoring: {str(e)}")
    
    def _check_resource_thresholds(self):
        """Check if resource usage exceeds thresholds."""
        latest_metrics = {
            'cpu_usage': self.metrics_history['cpu_usage'][-1]['value'],
            'memory_usage': self.metrics_history['memory_usage'][-1]['value']
        }
        
        if torch.cuda.is_available():
            latest_metrics['gpu_memory'] = self.metrics_history['gpu_memory'][-1]['value']
        
        for resource, value in latest_metrics.items():
            if value > self.alert_thresholds[resource]:
                self._log_alert(
                    f"High {resource}: {value:.1f}% exceeds threshold of "
                    f"{self.alert_thresholds[resource]}%"
                )
    
    def _check_training_anomalies(self, metric_name: str, value: float):
        """Check for anomalies in training metrics."""
        if len(self.metrics_history[metric_name]) < 10:
            return
        
        # Calculate moving average
        recent_values = [
            m['value'] for m in self.metrics_history[metric_name][-10:]
        ]
        moving_avg = np.mean(recent_values[:-1])
        
        # Check for spikes
        if value > moving_avg * self.alert_thresholds['training_loss_spike']:
            self._log_alert(
                f"Training anomaly detected: {metric_name} value {value:.3f} is "
                f"{value/moving_avg:.1f}x higher than moving average"
            )
    
    def _check_evaluation_performance(self, metric_name: str, value: float):
        """Check for significant drops in evaluation metrics."""
        eval_metrics = self.metrics_history['evaluation_metrics']
        if len(eval_metrics) < 2:
            return
        
        # Find previous value for same metric
        prev_values = [
            m['value'] for m in eval_metrics[:-1]
            if m['metric'] == metric_name
        ]
        
        if prev_values:
            prev_value = prev_values[-1]
            if (prev_value - value) > self.alert_thresholds['evaluation_drop']:
                self._log_alert(
                    f"Performance drop detected: {metric_name} dropped from "
                    f"{prev_value:.3f} to {value:.3f}"
                )
    
    def _log_alert(self, message: str):
        """Log an alert message."""
        alert_file = self.monitoring_dir / "alerts.jsonl"
        alert = {
            'timestamp': datetime.now().isoformat(),
            'message': message
        }
        
        with open(alert_file, 'a') as f:
            f.write(json.dumps(alert) + '\n')
        
        logger.warning(f"Alert: {message}")
    
    def _save_metrics(self):
        """Save metrics to disk."""
        metrics_file = self.monitoring_dir / "metrics.json"
        with open(metrics_file, 'w') as f:
            json.dump(self.metrics_history, f, indent=2)
    
    def _calculate_stats(self, metric_name: str) -> Dict:
        """Calculate statistics for a metric."""
        if not self.metrics_history[metric_name]:
            return {}
        
        values = [m['value'] for m in self.metrics_history[metric_name]]
        return {
            'current': values[-1],
            'mean': np.mean(values),
            'max': np.max(values),
            'min': np.min(values),
            'std': np.std(values)
        }
    
    def _get_latest_evaluation_metrics(self) -> Dict:
        """Get the most recent evaluation metrics."""
        metrics = {}
        for entry in reversed(self.metrics_history['evaluation_metrics']):
            metric_name = entry['metric']
            if metric_name not in metrics:
                metrics[metric_name] = entry['value']
        return metrics
    
    def _get_recent_alerts(self) -> List[Dict]:
        """Get recent alerts."""
        alert_file = self.monitoring_dir / "alerts.jsonl"
        if not alert_file.exists():
            return []
        
        alerts = []
        with open(alert_file, 'r') as f:
            for line in f:
                alerts.append(json.loads(line))
        
        return sorted(alerts, key=lambda x: x['timestamp'], reverse=True)[:10]
    
    def _generate_visualizations(self):
        """Generate visualization plots."""
        viz_dir = self.monitoring_dir / "visualizations"
        viz_dir.mkdir(exist_ok=True)
        
        # Resource usage over time
        plt.figure(figsize=(12, 6))
        for metric in ['cpu_usage', 'memory_usage', 'gpu_memory']:
            if self.metrics_history[metric]:
                values = [m['value'] for m in self.metrics_history[metric]]
                plt.plot(values, label=metric)
        plt.title("Resource Usage Over Time")
        plt.xlabel("Time")
        plt.ylabel("Percentage")
        plt.legend()
        plt.savefig(viz_dir / "resource_usage.png")
        plt.close()
        
        # Training loss
        if self.metrics_history['training_loss']:
            plt.figure(figsize=(12, 6))
            values = [m['value'] for m in self.metrics_history['training_loss']]
            plt.plot(values)
            plt.title("Training Loss")
            plt.xlabel("Step")
            plt.ylabel("Loss")
            plt.savefig(viz_dir / "training_loss.png")
            plt.close()
        
        # Evaluation metrics
        eval_metrics = self.metrics_history['evaluation_metrics']
        if eval_metrics:
            metrics_by_name = {}
            for entry in eval_metrics:
                if entry['metric'] not in metrics_by_name:
                    metrics_by_name[entry['metric']] = []
                metrics_by_name[entry['metric']].append(entry['value'])
            
            plt.figure(figsize=(12, 6))
            for metric_name, values in metrics_by_name.items():
                plt.plot(values, label=metric_name)
            plt.title("Evaluation Metrics")
            plt.xlabel("Evaluation")
            plt.ylabel("Value")
            plt.legend()
            plt.savefig(viz_dir / "evaluation_metrics.png")
            plt.close()
