#!/usr/bin/env python3
"""Module for managing visualization server and metrics."""
import multiprocessing
import os
import time
import subprocess
import sys
import logging
import socket
from pathlib import Path

# Add project root to Python path
ROOT_DIR = Path(__file__).parent.parent.parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from scripts.visualization.backend.metrics_manager import MetricsManager
from scripts.visualization.backend.system_monitor import SystemMonitor
from scripts.utils.path_config import ProjectPaths

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def find_free_port(start_port=8501, max_attempts=10):
    """Find a free port starting from start_port."""
    for port in range(start_port, start_port + max_attempts):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('', port))
                return port
        except OSError:
            continue
    raise OSError(f"No free ports found between {start_port} and {start_port + max_attempts - 1}")

class VisualizationManager:
    """Handles visualization server and metrics updates."""
    
    def __init__(self, project_paths, network_access=False):
        """Initialize visualization manager."""
        self.project_paths = project_paths
        self.network_access = network_access
        self.viz_process = None
        self.metrics_manager = MetricsManager()
        self.system_monitor = SystemMonitor()
        self.port = None
        
    def start_server(self):
        """Start the Streamlit visualization server."""
        try:
            # Find a free port
            self.port = find_free_port()
            
            # Start visualization in a separate process
            self.viz_process = multiprocessing.Process(
                target=self._run_visualizer
            )
            self.viz_process.start()
            time.sleep(3)  # Give server time to initialize
            
            self._print_access_info()
            return self.viz_process
            
        except Exception as e:
            logger.error(f"Failed to start visualization server: {e}")
            return None
            
    def _run_visualizer(self):
        """Run the visualization server process."""
        try:
            # Set up environment
            env = os.environ.copy()
            env["PYTHONPATH"] = str(self.project_paths.PROJECT_ROOT)
            
            # Build command
            cmd = self._build_server_command()
            
            # Start the process
            process = subprocess.Popen(cmd, env=env)
            time.sleep(2)  # Give the server time to start
            return process
        except Exception as e:
            logger.error(f"Error running visualizer: {e}")
            raise
        
    def _build_server_command(self):
        """Build the server command with appropriate options."""
        cmd = [
            sys.executable,
            "-m", "streamlit", "run",
            str(self.project_paths.VISUALIZATION_DIR / "app.py"),
            "--server.headless=true",
            f"--server.port={self.port}"
        ]
        
        if self.network_access:
            cmd.append("--server.address=0.0.0.0")
        else:
            cmd.append("--server.address=127.0.0.1")
            
        return cmd
        
    def _print_access_info(self):
        """Print server access information."""
        if self.network_access:
            print("\nVisualization dashboard will be available at:")
            print(f"http://localhost:{self.port} (local)")
            print(f"http://<your-ip>:{self.port} (network)\n")
        else:
            print("\nVisualization dashboard will be available at:")
            print(f"http://localhost:{self.port}\n")
            
    def cleanup_server(self):
        """Cleanup visualization server."""
        if self.viz_process:
            try:
                self.viz_process.terminate()
                self.viz_process.join(timeout=5)
                if self.viz_process.is_alive():
                    self.viz_process.kill()
                logger.info("Visualization server cleaned up successfully")
            except Exception as e:
                logger.error(f"Error cleaning up visualization: {e}")
            finally:
                self.viz_process = None
                
    def update_metrics(self, metrics: dict):
        """Update training metrics in visualization."""
        try:
            self.metrics_manager.save_training_metrics(metrics)
        except Exception as e:
            logger.error(f"Error updating metrics: {e}")
