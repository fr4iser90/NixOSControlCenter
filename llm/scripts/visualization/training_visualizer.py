#!/usr/bin/env python3
import streamlit as st
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots
import pandas as pd
import json
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional
import numpy as np
import sys
import os
import time

# Add project root to Python path
ROOT_DIR = Path(__file__).parent.parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from scripts.utils.path_config import ProjectPaths

class TrainingVisualizer:
    def __init__(self):
        self.metrics_dir = ProjectPaths.METRICS_DIR
        self.metrics_dir.mkdir(exist_ok=True)
        
    def save_training_metrics(self, step: int, metrics: Dict):
        """Save training metrics for visualization."""
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

def run_visualization_server():
    """Run the visualization dashboard."""
    try:
        st.set_page_config(page_title="NixOS Model Training Visualizer", layout="wide")
        
        st.title("NixOS Model Training Visualizer")
        st.markdown("""
        This dashboard provides real-time insights into the NixOS model training process.
        Monitor training progress, dataset quality, and model performance all in one place.
        """)
        
        # Add auto-refresh controls to sidebar
        with st.sidebar:
            st.header("Dashboard Controls")
            auto_refresh = st.checkbox("Enable auto-refresh", value=True)
            if auto_refresh:
                refresh_interval = st.slider(
                    "Refresh interval (seconds)",
                    min_value=1,
                    max_value=60,
                    value=5
                )
                st.write(f"Auto-refreshing every {refresh_interval} seconds")
                time.sleep(refresh_interval)
                st.rerun()
        
        # Load and display metrics
        visualizer = TrainingVisualizer()
        try:
            metrics_df = visualizer.load_training_metrics()
            
            if metrics_df.empty:
                st.info("Waiting for training metrics... The dashboard will update automatically when training starts.")
                return
                
            # Create main metrics display
            col1, col2, col3 = st.columns(3)
            
            with col1:
                if 'train_loss' in metrics_df:
                    latest_loss = metrics_df['train_loss'].iloc[-1]
                    st.metric(
                        "Current Training Loss",
                        f"{latest_loss:.4f}",
                        delta=f"{latest_loss - metrics_df['train_loss'].iloc[-2]:.4f}" if len(metrics_df) > 1 else None
                    )
                    
            with col2:
                if 'learning_rate' in metrics_df:
                    latest_lr = metrics_df['learning_rate'].iloc[-1]
                    st.metric("Learning Rate", f"{latest_lr:.6f}")
                    
            with col3:
                if 'batch_size' in metrics_df:
                    latest_bs = metrics_df['batch_size'].iloc[-1]
                    st.metric("Batch Size", str(latest_bs))
            
            # Create training progress plots
            st.subheader("Training Progress")
            
            # Use tabs for different metric views
            tab1, tab2 = st.tabs(["Training Metrics", "System Metrics"])
            
            with tab1:
                training_fig = make_subplots(
                    rows=1, cols=2,
                    subplot_titles=("Training Loss", "Learning Rate")
                )
                
                if 'train_loss' in metrics_df:
                    training_fig.add_trace(
                        go.Scatter(
                            x=metrics_df['step'],
                            y=metrics_df['train_loss'],
                            name="Training Loss",
                            line=dict(color="blue")
                        ),
                        row=1, col=1
                    )
                    
                if 'learning_rate' in metrics_df:
                    training_fig.add_trace(
                        go.Scatter(
                            x=metrics_df['step'],
                            y=metrics_df['learning_rate'],
                            name="Learning Rate",
                            line=dict(color="green")
                        ),
                        row=1, col=2
                    )
                    
                training_fig.update_layout(height=400, showlegend=True)
                st.plotly_chart(training_fig, use_container_width=True)
            
            with tab2:
                system_fig = make_subplots(
                    rows=1, cols=2,
                    subplot_titles=("Batch Size", "GPU Memory (if available)")
                )
                
                if 'batch_size' in metrics_df:
                    system_fig.add_trace(
                        go.Scatter(
                            x=metrics_df['step'],
                            y=metrics_df['batch_size'],
                            name="Batch Size",
                            line=dict(color="purple")
                        ),
                        row=1, col=1
                    )
                    
                if 'gpu_memory_used' in metrics_df:
                    system_fig.add_trace(
                        go.Scatter(
                            x=metrics_df['step'],
                            y=metrics_df['gpu_memory_used'],
                            name="GPU Memory (GB)",
                            line=dict(color="orange")
                        ),
                        row=1, col=2
                    )
                    
                system_fig.update_layout(height=400, showlegend=True)
                st.plotly_chart(system_fig, use_container_width=True)
                
        except Exception as e:
            st.error(f"Error loading metrics: {str(e)}")
            if auto_refresh:
                st.info("Will attempt to reload in a few seconds...")
                
    except Exception as e:
        st.error(f"Dashboard error: {str(e)}")
        if st.button("Retry"):
            st.rerun()

if __name__ == "__main__":
    run_visualization_server()
