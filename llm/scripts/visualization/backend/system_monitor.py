"""Backend service for system monitoring."""
import psutil
import torch
from typing import Dict

class SystemMonitor:
    """Monitors system resources including CPU, GPU, and memory."""
    
    def get_system_metrics(self) -> Dict:
        """Get current system metrics."""
        metrics = {
            'gpu_available': False,
            'gpu_memory_used': 0,
            'gpu_memory_total': 0,
            'gpu_utilization': 0,
            'cpu_percent': 0,
            'memory_percent': 0,
            'disk_percent': 0,
            'process_info': [],
            'alerts': []
        }
        
        try:
            # GPU Metrics
            if torch.cuda.is_available():
                metrics['gpu_available'] = True
                for i in range(torch.cuda.device_count()):
                    gpu_memory = torch.cuda.get_device_properties(i).total_memory / 1e9
                    gpu_memory_used = torch.cuda.memory_allocated(i) / 1e9
                    metrics['gpu_memory_total'] += gpu_memory
                    metrics['gpu_memory_used'] += gpu_memory_used
                    
                    if gpu_memory_used / gpu_memory > 0.9:
                        metrics['alerts'].append(f"GPU {i} memory usage is above 90%")
            
            # CPU and Memory Metrics
            metrics['cpu_percent'] = psutil.cpu_percent()
            metrics['memory_percent'] = psutil.virtual_memory().percent
            metrics['disk_percent'] = psutil.disk_usage('/').percent
            
            # Process Information
            process = psutil.Process()
            metrics['process_info'].append({
                'pid': process.pid,
                'name': process.name(),
                'cpu_percent': process.cpu_percent(),
                'memory_percent': process.memory_percent(),
                'status': process.status()
            })
            
            # Resource Usage Alerts
            if metrics['cpu_percent'] > 90:
                metrics['alerts'].append("CPU usage is above 90%")
            if metrics['memory_percent'] > 90:
                metrics['alerts'].append("Memory usage is above 90%")
            if metrics['disk_percent'] > 90:
                metrics['alerts'].append("Disk usage is above 90%")
                
        except Exception as e:
            metrics['alerts'].append(f"Error monitoring system: {str(e)}")
            
        return metrics
