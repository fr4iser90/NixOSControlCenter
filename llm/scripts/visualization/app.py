"""Main application for the NixOS Model Training Visualizer."""
import streamlit as st
from typing import Dict, Any

from backend.metrics_manager import MetricsManager
from backend.system_monitor import SystemMonitor
from backend.dataset_analyzer import DatasetAnalyzer
from frontend.training_view import TrainingView
from frontend.dataset_view import DatasetView
from frontend.system_view import SystemView
from frontend.history_view import HistoryView
from utils.config import VisualizerConfig
from utils.path_utils import ProjectPaths

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
                value=self.config.get('auto_refresh')
            )
            
            if auto_refresh:
                refresh_interval = st.slider(
                    "Refresh interval (seconds)",
                    min_value=1,
                    max_value=60,
                    value=self.config.get('refresh_interval')
                )
                self.config.update({
                    'auto_refresh': auto_refresh,
                    'refresh_interval': refresh_interval
                })
        
        try:
            # Display selected page
            if page == "Training Progress":
                metrics_df = self.metrics_manager.load_training_metrics()
                self.training_view.display_training_progress(metrics_df)
                
            elif page == "Dataset Analysis":
                stats = self.dataset_analyzer.get_dataset_stats()
                quality_metrics = self.dataset_analyzer.get_quality_metrics()
                self.dataset_view.display_dataset_analysis(stats, quality_metrics)
                
            elif page == "System Monitor":
                metrics = self.system_monitor.get_system_metrics()
                self.system_view.display_system_monitor(metrics)
                
            else:  # Training History
                runs = self.metrics_manager.get_training_runs()
                self.history_view.display_training_history(runs)
                
            # Handle auto-refresh
            if auto_refresh:
                st.empty()
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
