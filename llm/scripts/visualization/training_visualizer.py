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
from ..utils.path_config import ProjectPaths

class TrainingVisualizer:
    def __init__(self):
        self.metrics_dir = ProjectPaths.MODELS_DIR / "metrics"
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
    st.set_page_config(page_title="NixOS Model Training Visualizer", layout="wide")
    
    st.title("NixOS Model Training Visualizer")
    st.markdown("""
    This dashboard provides real-time insights into the NixOS model training process.
    Monitor training progress, dataset quality, and model performance all in one place.
    """)
    
    visualizer = TrainingVisualizer()
    metrics_df = visualizer.load_training_metrics()
    
    if metrics_df.empty:
        st.warning("No training metrics available yet. Start training to see visualizations.")
        return
        
    # Create main layout
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("Training Progress")
        
        # Training Loss Plot
        fig_loss = go.Figure()
        fig_loss.add_trace(go.Scatter(
            x=metrics_df["step"],
            y=metrics_df["train_loss"],
            name="Training Loss",
            line=dict(color="blue")
        ))
        fig_loss.add_trace(go.Scatter(
            x=metrics_df["step"],
            y=metrics_df["eval_loss"],
            name="Validation Loss",
            line=dict(color="red")
        ))
        fig_loss.update_layout(
            title="Training and Validation Loss",
            xaxis_title="Training Step",
            yaxis_title="Loss",
            hovermode="x unified"
        )
        st.plotly_chart(fig_loss, use_container_width=True)
        
        # Learning Rate Plot
        fig_lr = go.Figure()
        fig_lr.add_trace(go.Scatter(
            x=metrics_df["step"],
            y=metrics_df["learning_rate"],
            name="Learning Rate",
            line=dict(color="green")
        ))
        fig_lr.update_layout(
            title="Learning Rate Schedule",
            xaxis_title="Training Step",
            yaxis_title="Learning Rate",
            hovermode="x unified"
        )
        st.plotly_chart(fig_lr, use_container_width=True)
    
    with col2:
        st.subheader("Model Performance")
        
        # Batch Size Adaptation
        fig_batch = go.Figure()
        fig_batch.add_trace(go.Scatter(
            x=metrics_df["step"],
            y=metrics_df["batch_size"],
            name="Batch Size",
            line=dict(color="purple")
        ))
        fig_batch.update_layout(
            title="Dynamic Batch Size Adaptation",
            xaxis_title="Training Step",
            yaxis_title="Batch Size",
            hovermode="x unified"
        )
        st.plotly_chart(fig_batch, use_container_width=True)
        
        # GPU Memory Usage
        if "gpu_memory_used" in metrics_df.columns:
            fig_gpu = go.Figure()
            fig_gpu.add_trace(go.Scatter(
                x=metrics_df["step"],
                y=metrics_df["gpu_memory_used"],
                name="GPU Memory",
                fill="tozeroy",
                line=dict(color="orange")
            ))
            fig_gpu.update_layout(
                title="GPU Memory Usage",
                xaxis_title="Training Step",
                yaxis_title="Memory (GB)",
                hovermode="x unified"
            )
            st.plotly_chart(fig_gpu, use_container_width=True)
    
    # Dataset Quality Metrics
    st.subheader("Dataset Insights")
    col3, col4, col5 = st.columns(3)
    
    with col3:
        if "dataset_coverage" in metrics_df.columns:
            coverage_data = metrics_df["dataset_coverage"].iloc[-1]
            fig_coverage = px.pie(
                values=list(coverage_data.values()),
                names=list(coverage_data.keys()),
                title="Concept Coverage Distribution"
            )
            st.plotly_chart(fig_coverage, use_container_width=True)
    
    with col4:
        if "quality_scores" in metrics_df.columns:
            quality_data = metrics_df["quality_scores"].iloc[-1]
            fig_quality = go.Figure(data=[
                go.Bar(
                    x=list(quality_data.keys()),
                    y=list(quality_data.values()),
                    marker_color="lightblue"
                )
            ])
            fig_quality.update_layout(
                title="Dataset Quality Scores",
                xaxis_title="Metric",
                yaxis_title="Score"
            )
            st.plotly_chart(fig_quality, use_container_width=True)
    
    with col5:
        if "improvement_stats" in metrics_df.columns:
            improvement_data = metrics_df["improvement_stats"].iloc[-1]
            fig_improvements = go.Figure(data=[
                go.Bar(
                    x=list(improvement_data.keys()),
                    y=list(improvement_data.values()),
                    marker_color="lightgreen"
                )
            ])
            fig_improvements.update_layout(
                title="Dataset Improvements",
                xaxis_title="Category",
                yaxis_title="Count"
            )
            st.plotly_chart(fig_improvements, use_container_width=True)
    
    # Recent Updates Section
    st.subheader("Recent Updates")
    updates_container = st.container()
    
    with updates_container:
        recent_metrics = metrics_df.iloc[-5:].sort_values("step", ascending=False)
        for _, row in recent_metrics.iterrows():
            st.text(f"""
            Step {row['step']} | Loss: {row['train_loss']:.4f} | Val Loss: {row['eval_loss']:.4f}
            Batch Size: {row['batch_size']} | Learning Rate: {row['learning_rate']:.6f}
            Timestamp: {row['timestamp']}
            """)
            
    # Add auto-refresh button
    if st.button("Refresh Metrics"):
        st.experimental_rerun()
        
    # Add auto-refresh functionality
    st.markdown("""
        <script>
        function reload() {
            setTimeout(function () {
                window.location.reload();
            }, 30000);
        }
        reload();
        </script>
        """, unsafe_allow_html=True)

if __name__ == "__main__":
    run_visualization_server()
