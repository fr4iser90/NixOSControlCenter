"""Backend component for system resource monitoring."""
import psutil
import logging
from typing import Dict, List, Optional
from datetime import datetime
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import pandas as pd
import torch
import subprocess
from pathlib import Path

logger = logging.getLogger(__name__)

class SystemMonitor:
    """Monitor for system resources."""
    
    def __init__(self):
        """Initialize system monitor."""
        self.history_length = 100  # Keep last 100 measurements
        self.timestamps = []
        self.cpu_history = []
        self.memory_history = []
        self.gpu_history = []
        self.disk_history = []
        self.is_jetson = Path("/sys/devices/soc0/family").exists()
        
    def _get_jetson_gpu_info(self) -> Dict:
        """Get GPU information for Jetson devices using Tegra APIs.
        
        Returns:
            Dictionary with GPU metrics
        """
        try:
            # GPU Utilization
            with open("/sys/devices/gpu.0/load", "r") as f:
                gpu_util = int(f.read().strip())
                
            # GPU Frequency
            with open("/sys/devices/gpu.0/devfreq/gpu.0/cur_freq", "r") as f:
                gpu_freq = int(f.read().strip()) / 1000000  # Convert to MHz
                
            # GPU Memory
            total_mem = 0
            used_mem = 0
            
            # Read memory info from sysfs
            with open("/proc/meminfo", "r") as f:
                for line in f:
                    if "MemTotal" in line:
                        total_mem = int(line.split()[1]) / 1024  # Convert to MB
                    elif "MemAvailable" in line:
                        available_mem = int(line.split()[1]) / 1024
                        used_mem = total_mem - available_mem
                        
            return {
                "gpu_available": True,
                "gpu_utilization": gpu_util,
                "gpu_frequency": gpu_freq,
                "gpu_memory_total": total_mem / 1024,  # Convert to GB
                "gpu_memory_used": used_mem / 1024
            }
        except Exception as e:
            logger.error(f"Error getting Jetson GPU info: {str(e)}")
            return {
                "gpu_available": False,
                "gpu_utilization": 0,
                "gpu_memory_total": 0,
                "gpu_memory_used": 0
            }
            
    def _get_gpu_utilization(self) -> float:
        """Get GPU utilization.
        
        Returns:
            GPU utilization percentage
        """
        if self.is_jetson:
            return self._get_jetson_gpu_info()["gpu_utilization"]
            
        try:
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=utilization.gpu', '--format=csv,noheader,nounits'],
                capture_output=True,
                text=True,
                check=True
            )
            return float(result.stdout.strip())
        except:
            return 0.0
            
    def get_system_metrics(self) -> Dict:
        """Get current system metrics.
        
        Returns:
            Dictionary of system metrics including GPU, CPU, memory, disk usage,
            process information, and resource alerts.
        """
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
            if self.is_jetson:
                # Get Jetson GPU metrics
                gpu_info = self._get_jetson_gpu_info()
                metrics.update(gpu_info)
                if gpu_info["gpu_available"]:
                    logger.info("Jetson GPU detected")
                    logger.info(f"GPU Utilization: {gpu_info['gpu_utilization']}%")
                    logger.info(f"GPU Memory: {gpu_info['gpu_memory_used']:.1f}/{gpu_info['gpu_memory_total']:.1f} GB")
                    if "gpu_frequency" in gpu_info:
                        logger.info(f"GPU Frequency: {gpu_info['gpu_frequency']} MHz")
                        
            elif torch.cuda.is_available():
                # Standard NVIDIA GPU metrics
                metrics['gpu_available'] = True
                for i in range(torch.cuda.device_count()):
                    props = torch.cuda.get_device_properties(i)
                    gpu_memory = props.total_memory / 1e9
                    gpu_memory_used = torch.cuda.memory_allocated(i) / 1e9
                    
                    metrics['gpu_memory_total'] += gpu_memory
                    metrics['gpu_memory_used'] += gpu_memory_used
                    metrics['gpu_utilization'] = self._get_gpu_utilization()
                    
                    logger.info(f"GPU {i}: {props.name}")
                    logger.info(f"Memory: {gpu_memory_used:.1f}/{gpu_memory:.1f} GB")
                    logger.info(f"Utilization: {metrics['gpu_utilization']}%")
                    
                    if gpu_memory_used / gpu_memory > 0.9:
                        metrics['alerts'].append(f"GPU {i} memory usage is above 90%")
                        
            # CPU and Memory Metrics
            metrics['cpu_percent'] = psutil.cpu_percent()
            memory = psutil.virtual_memory()
            metrics['memory_percent'] = memory.percent
            metrics['memory_used'] = memory.used / 1e9
            metrics['memory_total'] = memory.total / 1e9
            
            # Disk Metrics
            disk = psutil.disk_usage('/')
            metrics['disk_percent'] = disk.percent
            metrics['disk_used'] = disk.used / 1e9
            metrics['disk_total'] = disk.total / 1e9
            
            # Process Information
            process = psutil.Process()
            metrics['process_info'].append({
                'pid': process.pid,
                'name': process.name(),
                'cpu_percent': process.cpu_percent(),
                'memory_percent': process.memory_percent(),
                'status': process.status(),
                'threads': process.num_threads(),
                'open_files': len(process.open_files()),
                'connections': len(process.connections())
            })
            
            # Resource Usage Alerts
            if metrics['cpu_percent'] > 90:
                metrics['alerts'].append("CPU usage is above 90%")
            if metrics['memory_percent'] > 90:
                metrics['alerts'].append("Memory usage is above 90%")
            if metrics['disk_percent'] > 90:
                metrics['alerts'].append("Disk usage is above 90%")
                
            # Update history with timestamp
            current_time = datetime.now()
            self.timestamps.append(current_time)
            self.cpu_history.append(metrics['cpu_percent'])
            self.memory_history.append(metrics['memory_percent'])
            self.disk_history.append(metrics['disk_percent'])
            if metrics['gpu_available']:
                self.gpu_history.append(metrics['gpu_utilization'])
            elif len(self.gpu_history) > 0:
                self.gpu_history.append(None)
                
            # Keep history length fixed
            if len(self.timestamps) > self.history_length:
                self.timestamps.pop(0)
            if len(self.cpu_history) > self.history_length:
                self.cpu_history.pop(0)
            if len(self.memory_history) > self.history_length:
                self.memory_history.pop(0)
            if len(self.disk_history) > self.history_length:
                self.disk_history.pop(0)
            if len(self.gpu_history) > self.history_length:
                self.gpu_history.pop(0)
                
        except Exception as e:
            logger.error(f"Error monitoring system: {str(e)}")
            metrics['alerts'].append(f"Error monitoring system: {str(e)}")
            
        return metrics
        
    def plot_resource_history(self) -> Optional[go.Figure]:
        """Plot resource usage history.
        
        Returns:
            Plotly figure with CPU, memory, disk, and GPU usage over time
        """
        if not self.cpu_history:  # No data yet
            return None
            
        df = pd.DataFrame({
            'time': self.timestamps,
            'CPU': self.cpu_history,
            'Memory': self.memory_history,
            'Disk': self.disk_history
        })
        
        has_gpu = len(self.gpu_history) > 0 and any(x is not None for x in self.gpu_history)
        
        fig = make_subplots(
            rows=2, cols=2,
            subplot_titles=(
                "CPU Usage",
                "Memory Usage",
                "Disk Usage",
                "GPU Usage" if has_gpu else None
            )
        )
        
        # CPU Usage
        fig.add_trace(
            go.Scatter(x=df['time'], y=df['CPU'],
                      name='CPU %', mode='lines'),
            row=1, col=1
        )
        
        # Memory Usage
        fig.add_trace(
            go.Scatter(x=df['time'], y=df['Memory'],
                      name='Memory %', mode='lines'),
            row=1, col=2
        )
        
        # Disk Usage
        fig.add_trace(
            go.Scatter(x=df['time'], y=df['Disk'],
                      name='Disk %', mode='lines'),
            row=2, col=1
        )
        
        # GPU Usage if available
        if has_gpu:
            df['GPU'] = pd.Series(self.gpu_history)
            fig.add_trace(
                go.Scatter(x=df['time'], y=df['GPU'],
                          name='GPU %', mode='lines'),
                row=2, col=2
            )
            
        # Update layout and axes
        fig.update_layout(
            title="System Resource History",
            height=800,
            showlegend=True,
            hovermode='x unified'
        )
        
        # Update all y-axes to show percentages from 0-100
        for i in range(1, 3):
            for j in range(1, 3):
                fig.update_yaxes(range=[0, 100], row=i, col=j)
                
        return fig
        
    def get_training_processes(self) -> List[Dict]:
        """Get information about training processes.
        
        Returns:
            List of process information including detailed metrics
        """
        training_processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent', 'status']):
            try:
                if 'python' in proc.info['name'].lower():
                    process = psutil.Process(proc.info['pid'])
                    training_processes.append({
                        'pid': proc.info['pid'],
                        'name': proc.info['name'],
                        'cpu': proc.info['cpu_percent'],
                        'memory': proc.info['memory_percent'],
                        'status': proc.info['status'],
                        'threads': process.num_threads(),
                        'open_files': len(process.open_files()),
                        'connections': len(process.connections()),
                        'create_time': process.create_time()
                    })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
                
        return training_processes
