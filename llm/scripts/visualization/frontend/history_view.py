"""Frontend component for training history visualization."""
import streamlit as st
import plotly.graph_objects as go
import plotly.express as px
import pandas as pd
from typing import Dict, List
from ..backend.metrics_manager import MetricsManager

class HistoryView:
    """Handles the training history visualization interface."""
    
    def __init__(self, metrics_manager: MetricsManager):
        """Initialize history view.
        
        Args:
            metrics_manager: Metrics manager instance
        """
        self.metrics_manager = metrics_manager
        
    def display_training_history(self, runs: List[Dict]):
        """Display comprehensive training history and comparisons."""
        st.title("Training History")
        
        if not runs:
            st.warning("No training history available.")
            return
        
        runs_df = pd.DataFrame(runs)
        self._display_runs_overview(runs_df)
        self._display_run_comparisons(runs_df)
        
    def _display_runs_overview(self, runs_df: pd.DataFrame):
        """Display overview of all training runs."""
        st.header("Training Runs Overview")
        
        # Format the dataframe for display
        display_df = runs_df.copy()
        if 'best_loss' in display_df:
            display_df['best_loss'] = display_df['best_loss'].map('{:.4f}'.format)
            
        st.dataframe(display_df)
        
    def _display_run_comparisons(self, runs_df: pd.DataFrame):
        """Display interactive comparisons between selected runs."""
        selected_runs = st.multiselect(
            "Select runs to compare",
            options=runs_df['run_id'].tolist(),
            default=runs_df['run_id'].head(2).tolist()
        )
        
        if not selected_runs:
            return
            
        comparison_df = runs_df[runs_df['run_id'].isin(selected_runs)]
        
        # Loss Comparison
        st.subheader("Training Loss Comparison")
        fig = go.Figure()
        for run_id in selected_runs:
            run_data = comparison_df[comparison_df['run_id'] == run_id]
            fig.add_trace(go.Scatter(
                x=run_data['steps'],
                y=run_data['loss'],
                name=f"Run {run_id}"
            ))
        st.plotly_chart(fig, use_container_width=True)
        
        # Learning Rate Comparison
        if 'learning_rate' in comparison_df:
            st.subheader("Learning Rate Schedule")
            fig = go.Figure()
            for run_id in selected_runs:
                run_data = comparison_df[comparison_df['run_id'] == run_id]
                fig.add_trace(go.Scatter(
                    x=run_data['steps'],
                    y=run_data['learning_rate'],
                    name=f"Run {run_id}"
                ))
            st.plotly_chart(fig, use_container_width=True)
        
        # Training Speed Comparison
        if 'training_speed' in comparison_df:
            st.subheader("Training Speed")
            fig = go.Figure()
            for run_id in selected_runs:
                run_data = comparison_df[comparison_df['run_id'] == run_id]
                fig.add_trace(go.Scatter(
                    x=run_data['steps'],
                    y=run_data['training_speed'],
                    name=f"Run {run_id}"
                ))
            st.plotly_chart(fig, use_container_width=True)
            
        # Detailed Metrics Table
        st.header("Detailed Metrics")
        metrics_comparison = []
        for run_id in selected_runs:
            run_data = comparison_df[comparison_df['run_id'] == run_id].iloc[0]
            metrics_comparison.append({
                'Run ID': run_id,
                'Best Loss': run_data.get('best_loss', 'N/A'),
                'Total Steps': run_data.get('total_steps', 'N/A'),
                'Training Time': run_data.get('training_time', 'N/A'),
                'Avg Training Speed': run_data.get('avg_training_speed', 'N/A')
            })
        st.table(pd.DataFrame(metrics_comparison))
