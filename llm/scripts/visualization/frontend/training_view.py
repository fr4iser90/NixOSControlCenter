"""Frontend component for training visualization."""
import streamlit as st
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import pandas as pd
from typing import Dict

class TrainingView:
    """Handles the training progress visualization interface."""
    
    def display_training_progress(self, metrics_df: pd.DataFrame):
        """Display real-time training progress with enhanced metrics."""
        st.title("Training Progress")
        
        if metrics_df.empty:
            st.warning("No training metrics available yet.")
            return
            
        self._display_current_metrics(metrics_df)
        self._display_training_plots(metrics_df)
        self._display_advanced_metrics(metrics_df)
        
    def _display_current_metrics(self, metrics_df: pd.DataFrame):
        """Display current training metrics."""
        latest = metrics_df.iloc[-1]
        col1, col2, col3 = st.columns(3)
        
        with col1:
            st.metric("Current Loss", f"{latest.get('loss', 'N/A'):.4f}")
        with col2:
            st.metric("Training Steps", latest.get('step', 'N/A'))
        with col3:
            if 'learning_rate' in latest:
                st.metric("Learning Rate", f"{latest['learning_rate']:.2e}")
                
    def _display_training_plots(self, metrics_df: pd.DataFrame):
        """Display interactive training plots."""
        fig = make_subplots(
            rows=2, cols=2,
            subplot_titles=("Training Loss", "Learning Rate", 
                          "GPU Memory Usage", "Training Speed"),
            vertical_spacing=0.15
        )
        
        # Training Loss
        fig.add_trace(
            go.Scatter(x=metrics_df['step'], y=metrics_df['loss'], 
                      name="Loss"),
            row=1, col=1
        )
        
        # Learning Rate
        if 'learning_rate' in metrics_df:
            fig.add_trace(
                go.Scatter(x=metrics_df['step'], 
                          y=metrics_df['learning_rate'], 
                          name="LR"),
                row=1, col=2
            )
        
        # GPU Memory
        if 'gpu_memory_used' in metrics_df:
            fig.add_trace(
                go.Scatter(x=metrics_df['step'], 
                          y=metrics_df['gpu_memory_used'] / 1e9, 
                          name="GPU Memory (GB)"),
                row=2, col=1
            )
        
        # Training Speed
        if 'step' in metrics_df and 'timestamp' in metrics_df:
            speed = self._calculate_training_speed(metrics_df)
            fig.add_trace(
                go.Scatter(x=metrics_df['step'], y=speed, 
                          name="Steps/sec"),
                row=2, col=2
            )
        
        fig.update_layout(height=800, showlegend=True)
        st.plotly_chart(fig, use_container_width=True)
        
    def _display_advanced_metrics(self, metrics_df: pd.DataFrame):
        """Display advanced metrics section."""
        with st.expander("Advanced Metrics"):
            st.dataframe(metrics_df.tail(100).sort_index(ascending=False))
            
        if st.button("Export Metrics"):
            csv = metrics_df.to_csv(index=False)
            st.download_button(
                "Download CSV",
                csv,
                "training_metrics.csv",
                "text/csv",
                key='download-csv'
            )
            
    def _calculate_training_speed(self, metrics_df: pd.DataFrame) -> pd.Series:
        """Calculate training speed from metrics."""
        metrics_df['timestamp'] = pd.to_datetime(metrics_df['timestamp'])
        speed = []
        for i in range(1, len(metrics_df)):
            time_diff = (metrics_df['timestamp'].iloc[i] - 
                        metrics_df['timestamp'].iloc[i-1]).total_seconds()
            step_diff = metrics_df['step'].iloc[i] - metrics_df['step'].iloc[i-1]
            speed.append(step_diff / time_diff if time_diff > 0 else 0)
        return pd.Series([0] + speed)
