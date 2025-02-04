#!/usr/bin/env python3
import streamlit as st
import plotly.graph_objects as go
import plotly.express as px
from pathlib import Path
import json
import os
import sys
import torch
from datetime import datetime
import pandas as pd
import humanize

# Add project root to Python path
ROOT_DIR = Path(__file__).parent.parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from scripts.utils.path_config import ProjectPaths

class ModelDashboard:
    def __init__(self):
        self.models_dir = ProjectPaths.MODELS_DIR
        self.data_dir = ProjectPaths.DATA_DIR
        
    def get_model_info(self, model_path):
        """Get information about a specific model."""
        info = {
            'name': model_path.name,
            'size': humanize.naturalsize(sum(f.stat().st_size for f in model_path.rglob('*') if f.is_file())),
            'last_modified': datetime.fromtimestamp(model_path.stat().st_mtime).strftime('%Y-%m-%d %H:%M:%S'),
            'files': len(list(model_path.rglob('*'))),
        }
        
        # Try to load config
        config_path = model_path / 'config.json'
        if config_path.exists():
            try:
                with open(config_path) as f:
                    config = json.load(f)
                info.update({
                    'architecture': config.get('architectures', ['Unknown'])[0],
                    'vocab_size': config.get('vocab_size', 'Unknown'),
                    'hidden_size': config.get('hidden_size', 'Unknown'),
                })
            except:
                pass
                
        # Check for training metrics
        metrics_path = model_path / 'training_metrics.json'
        if metrics_path.exists():
            try:
                with open(metrics_path) as f:
                    metrics = json.load(f)
                info.update({
                    'best_loss': metrics.get('best_loss', 'Unknown'),
                    'training_steps': metrics.get('total_steps', 'Unknown'),
                    'training_time': metrics.get('total_time', 'Unknown'),
                })
            except:
                pass
                
        return info
        
    def get_dataset_info(self, dataset_path):
        """Get information about a dataset directory."""
        info = {
            'name': dataset_path.name,
            'size': humanize.naturalsize(sum(f.stat().st_size for f in dataset_path.rglob('*') if f.is_file())),
            'files': len(list(dataset_path.rglob('*.jsonl'))),
            'last_modified': datetime.fromtimestamp(dataset_path.stat().st_mtime).strftime('%Y-%m-%d %H:%M:%S'),
        }
        
        # Try to load dataset statistics if available
        stats_path = dataset_path / 'statistics.json'
        if stats_path.exists():
            try:
                with open(stats_path) as f:
                    stats = json.load(f)
                info.update({
                    'total_examples': stats.get('total_examples', 0),
                    'avg_length': stats.get('avg_length', 0),
                    'concepts': len(stats.get('concepts', [])),
                })
            except:
                pass
                
        return info

def run_dashboard():
    """Run the model information dashboard."""
    st.set_page_config(page_title="NixOS Model Dashboard", layout="wide")
    
    st.title("NixOS Model Dashboard")
    st.markdown("""
    This dashboard provides an overview of all trained models and datasets in the NixOS project.
    Monitor model versions, sizes, and training metrics all in one place.
    """)
    
    dashboard = ModelDashboard()
    
    # Create tabs for different views
    model_tab, dataset_tab, system_tab = st.tabs(["Models", "Datasets", "System Info"])
    
    with model_tab:
        st.header("Available Models")
        
        # Get all model directories
        model_dirs = [d for d in dashboard.models_dir.iterdir() if d.is_dir()]
        if not model_dirs:
            st.info("No models found. Start training to see model information here.")
            return
            
        # Create model cards
        for model_dir in model_dirs:
            with st.expander(f"📊 {model_dir.name}", expanded=True):
                info = dashboard.get_model_info(model_dir)
                
                # Create columns for layout
                col1, col2, col3 = st.columns(3)
                
                with col1:
                    st.metric("Model Size", info['size'])
                    st.metric("Files", info['files'])
                    
                with col2:
                    if 'best_loss' in info:
                        st.metric("Best Loss", f"{info['best_loss']:.4f}")
                    if 'training_steps' in info:
                        st.metric("Training Steps", info['training_steps'])
                        
                with col3:
                    st.metric("Last Modified", info['last_modified'])
                    if 'architecture' in info:
                        st.metric("Architecture", info['architecture'])
                
                # Show detailed config if available
                if 'hidden_size' in info:
                    st.markdown("#### Model Configuration")
                    st.json({
                        'vocab_size': info['vocab_size'],
                        'hidden_size': info['hidden_size'],
                    })
                    
                # Show training metrics if available
                if 'training_time' in info:
                    st.markdown("#### Training Statistics")
                    st.json({
                        'total_time': info['training_time'],
                        'best_loss': info.get('best_loss', 'Unknown'),
                        'total_steps': info.get('training_steps', 'Unknown'),
                    })
    
    with dataset_tab:
        st.header("Available Datasets")
        
        # Get all dataset directories
        dataset_dirs = [d for d in dashboard.data_dir.iterdir() if d.is_dir()]
        if not dataset_dirs:
            st.info("No datasets found. Add data to see dataset information here.")
            return
            
        # Create dataset cards
        for dataset_dir in dataset_dirs:
            with st.expander(f"📚 {dataset_dir.name}", expanded=True):
                info = dashboard.get_dataset_info(dataset_dir)
                
                # Create columns for layout
                col1, col2 = st.columns(2)
                
                with col1:
                    st.metric("Dataset Size", info['size'])
                    st.metric("Number of Files", info['files'])
                    
                with col2:
                    if 'total_examples' in info:
                        st.metric("Total Examples", info['total_examples'])
                    if 'concepts' in info:
                        st.metric("Number of Concepts", info['concepts'])
                
                # Show detailed statistics if available
                if 'avg_length' in info:
                    st.markdown("#### Dataset Statistics")
                    st.json({
                        'average_length': info['avg_length'],
                        'total_examples': info.get('total_examples', 'Unknown'),
                        'last_modified': info['last_modified'],
                    })
    
    with system_tab:
        st.header("System Information")
        
        # GPU Information
        st.subheader("GPU Status")
        if torch.cuda.is_available():
            for i in range(torch.cuda.device_count()):
                gpu_props = torch.cuda.get_device_properties(i)
                st.metric(f"GPU {i}", gpu_props.name)
                col1, col2 = st.columns(2)
                with col1:
                    memory_used = torch.cuda.memory_allocated(i) / 1024**3
                    st.metric("Memory Used (GB)", f"{memory_used:.2f}")
                with col2:
                    memory_total = gpu_props.total_memory / 1024**3
                    st.metric("Total Memory (GB)", f"{memory_total:.2f}")
        else:
            st.info("No GPU available. Using CPU only.")
        
        # Storage Information
        st.subheader("Storage Status")
        models_usage = sum(f.stat().st_size for f in dashboard.models_dir.rglob('*') if f.is_file())
        data_usage = sum(f.stat().st_size for f in dashboard.data_dir.rglob('*') if f.is_file())
        
        col1, col2 = st.columns(2)
        with col1:
            st.metric("Models Storage", humanize.naturalsize(models_usage))
        with col2:
            st.metric("Data Storage", humanize.naturalsize(data_usage))

if __name__ == "__main__":
    run_dashboard()
