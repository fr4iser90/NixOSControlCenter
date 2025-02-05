"""Module for managing visualization server and metrics."""
import multiprocessing
import os
import time
import subprocess
import sys
import logging
from pathlib import Path

logger = logging.getLogger(__name__)

class VisualizationManager:
    """Handles visualization server and metrics updates."""
    
    def __init__(self, project_paths, network_access=False):
        """Initialize visualization manager."""
        self.project_paths = project_paths
        self.network_access = network_access
        self.viz_process = None
        
    def start_server(self):
        """Start the Streamlit visualization server."""
        try:
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
        # Set up environment
        env = os.environ.copy()
        env["PYTHONPATH"] = str(self.project_paths.PROJECT_ROOT)
        
        # Build command
        cmd = self._build_server_command()
        
        # Start the process
        process = subprocess.Popen(cmd, env=env)
        time.sleep(2)  # Give the server time to start
        return process
        
    def _build_server_command(self):
        """Build the server command with appropriate options."""
        cmd = [
            sys.executable,
            "-m", "streamlit", "run",
            str(self.project_paths.VISUALIZATION_DIR / "app.py"),
            "--server.headless=true",
            "--server.port=8501"
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
            print("http://localhost:8501 (local)")
            print("http://<your-ip>:8501 (network)\n")
        else:
            print("\nVisualization dashboard will be available at:")
            print("http://localhost:8501\n")
            
    def cleanup_server(self):
        """Cleanup visualization server."""
        if self.viz_process:
            try:
                self.viz_process.terminate()
                self.viz_process.join()
                logger.info("Visualization server cleaned up successfully")
            except Exception as e:
                logger.error(f"Error cleaning up visualization: {e}")
            finally:
                self.viz_process = None
                
    def update_metrics(self, metrics: dict):
        """Update training metrics in visualization.
        
        This is a placeholder - implement based on your specific
        visualization needs and metrics structure.
        """
        # TODO: Implement metrics update logic
        pass
