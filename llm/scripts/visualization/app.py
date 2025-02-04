"""Main application for the NixOS Model Training Visualizer."""
import streamlit as st
from typing import Dict, Any
import time

# Add project root to Python path
from pathlib import Path
import sys
ROOT_DIR = Path(__file__).parent.parent.parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from llm.scripts.visualization.backend.metrics_manager import MetricsManager
from llm.scripts.visualization.backend.system_monitor import SystemMonitor
from llm.scripts.visualization.backend.dataset_analyzer import DatasetAnalyzer
from llm.scripts.visualization.frontend.training_view import TrainingView
from llm.scripts.visualization.frontend.dataset_view import DatasetView
from llm.scripts.visualization.frontend.system_view import SystemView
from llm.scripts.visualization.frontend.history_view import HistoryView
from llm.scripts.visualization.utils.config import VisualizerConfig
from llm.scripts.utils.path_config import ProjectPaths

class NixOSVisualizer:
    """Main application class for the NixOS Model Training Visualizer."""
    
    def __init__(self):
        """Initialize visualization components."""
        # Ensure directories exist
        ProjectPaths.ensure_directories()
        
        # Initialize configuration
        self.config = VisualizerConfig()
        
        # Initialize backend services
        self.metrics_manager = MetricsManager()
        self.system_monitor = SystemMonitor()
        self.dataset_analyzer = DatasetAnalyzer()
        
        # Initialize frontend views
        self.training_view = TrainingView()
        self.dataset_view = DatasetView()
        self.system_view = SystemView()
        self.history_view = HistoryView()
        
    def setup_page(self):
        """Setup the Streamlit page configuration."""
        st.set_page_config(
            page_title="NixOS Model Training Visualizer",
            page_icon="🤖",
            layout="wide",
            initial_sidebar_state=self.config.get('sidebar_state')
        )
        
        # Configure network access if specified
        if self.config.get('network_access', False):
            import streamlit.config as st_config
            st_config.set_option('server.address', '0.0.0.0')
        
    def run(self):
        """Run the visualization dashboard."""
        self.setup_page()
        
        # Add navigation in sidebar
        with st.sidebar:
            st.title("Navigation")
            page = st.radio("Go to", [
                "Training Progress",
                "Dataset Analysis",
                "System Monitor",
                "Training History"
            ])
            
            # Global controls
            st.header("Dashboard Controls")
            auto_refresh = st.checkbox(
                "Enable auto-refresh",
                value=self.config.get('auto_refresh', True)
            )
            
            if auto_refresh:
                refresh_interval = st.slider(
                    "Refresh interval (seconds)",
                    min_value=1,
                    max_value=60,
                    value=self.config.get('refresh_interval', 5)
                )
                self.config.update({
                    'auto_refresh': auto_refresh,
                    'refresh_interval': refresh_interval
                })
        
        try:
            # Display selected page
            if page == "Training Progress":
                metrics_df = self.metrics_manager.load_training_metrics()
                if metrics_df is not None and not metrics_df.empty:
                    self.training_view.display_training_progress(metrics_df)
                else:
                    st.info("Waiting for training metrics... Training data will appear here once available.")
                    
            elif page == "Dataset Analysis":
                stats = self.dataset_analyzer.get_dataset_stats()
                quality_metrics = self.dataset_analyzer.get_quality_metrics()
                if stats:
                    self.dataset_view.display_dataset_analysis(stats, quality_metrics)
                else:
                    st.info("Analyzing dataset... Statistics will appear here once available.")
                
            elif page == "System Monitor":
                metrics = self.system_monitor.get_system_metrics()
                self.system_view.display_system_monitor(metrics)
                
            else:  # Training History
                runs = self.metrics_manager.get_training_runs()
                if runs:
                    self.history_view.display_training_history(runs)
                else:
                    st.info("No training history available yet. Previous training runs will appear here.")
                
            # Handle auto-refresh
            if auto_refresh:
                time.sleep(0.1)  # Small delay to prevent excessive CPU usage
                st.rerun()
                
        except Exception as e:
            st.error(f"Dashboard error: {str(e)}")
            if st.button("Retry"):
                st.rerun()

def main():
    """Main entry point for the visualization dashboard."""
    visualizer = NixOSVisualizer()
    visualizer.run()

if __name__ == "__main__":
    main()
