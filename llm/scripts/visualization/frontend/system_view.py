"""Frontend component for system monitoring visualization."""
import streamlit as st
import plotly.express as px
import pandas as pd
from typing import Dict

class SystemView:
    """Handles the system monitoring visualization interface."""
    
    def display_system_monitor(self, metrics: Dict):
        """Display comprehensive system resource monitoring."""
        st.title("System Monitor")
        
        self._display_gpu_metrics(metrics)
        self._display_system_metrics(metrics)
        self._display_process_info(metrics)
        self._display_alerts(metrics)
        self._setup_auto_refresh()
        
    def _display_gpu_metrics(self, metrics: Dict):
        """Display GPU resource metrics."""
        st.header("GPU Resources")
        
        if metrics['gpu_available']:
            cols = st.columns(3)
            with cols[0]:
                st.metric("GPU Memory Used", 
                         f"{metrics['gpu_memory_used']:.1f} GB")
            with cols[1]:
                st.metric("GPU Memory Total", 
                         f"{metrics['gpu_memory_total']:.1f} GB")
            with cols[2]:
                utilization = (metrics['gpu_memory_used'] / 
                             metrics['gpu_memory_total'] * 100)
                st.metric("GPU Utilization", 
                         f"{utilization:.1f}%")
                
            # GPU Memory Timeline
            if 'gpu_memory_history' in metrics:
                st.subheader("GPU Memory Usage Over Time")
                fig = px.line(
                    x=metrics['gpu_memory_history']['timestamp'],
                    y=metrics['gpu_memory_history']['memory_used'],
                    title="GPU Memory Usage (GB)"
                )
                st.plotly_chart(fig, use_container_width=True)
        else:
            st.warning("No GPU detected")
            
    def _display_system_metrics(self, metrics: Dict):
        """Display CPU, memory, and disk metrics."""
        st.header("System Resources")
        cols = st.columns(3)
        
        with cols[0]:
            st.metric("CPU Usage", 
                     f"{metrics['cpu_percent']:.1f}%",
                     delta="warning" if metrics['cpu_percent'] > 80 else None)
        with cols[1]:
            st.metric("Memory Usage", 
                     f"{metrics['memory_percent']:.1f}%",
                     delta="warning" if metrics['memory_percent'] > 80 else None)
        with cols[2]:
            st.metric("Disk Usage", 
                     f"{metrics['disk_percent']:.1f}%",
                     delta="warning" if metrics['disk_percent'] > 80 else None)
            
    def _display_process_info(self, metrics: Dict):
        """Display process information."""
        st.header("Process Information")
        if metrics['process_info']:
            process_df = pd.DataFrame(metrics['process_info'])
            
            # Format the dataframe
            if not process_df.empty:
                process_df['cpu_percent'] = process_df['cpu_percent'].map(
                    '{:.1f}%'.format)
                process_df['memory_percent'] = process_df['memory_percent'].map(
                    '{:.1f}%'.format)
                
            st.dataframe(process_df)
            
    def _display_alerts(self, metrics: Dict):
        """Display system alerts."""
        if metrics['alerts']:
            st.header("System Alerts")
            for alert in metrics['alerts']:
                st.warning(alert)
                
    def _setup_auto_refresh(self):
        """Setup auto-refresh functionality."""
        with st.sidebar:
            if st.checkbox("Enable auto-refresh", value=True):
                refresh_interval = st.slider(
                    "Refresh interval (seconds)",
                    min_value=1,
                    max_value=60,
                    value=5
                )
                st.write(f"Auto-refreshing every {refresh_interval} seconds")
                st.rerun()
