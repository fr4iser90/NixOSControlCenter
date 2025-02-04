"""Frontend component for training visualization."""
import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import pandas as pd

class TrainingView:
    """Handles the training progress visualization interface."""
    
    def display_training_progress(self, metrics_df: pd.DataFrame):
        """Display comprehensive training progress."""
        st.title("Training Progress")
        
        if metrics_df.empty:
            st.info("Waiting for training metrics...")
            return
            
        # Create metrics dashboard
        col1, col2, col3 = st.columns(3)
        
        with col1:
            latest_loss = metrics_df['loss'].iloc[-1]
            min_loss = metrics_df['loss'].min()
            st.metric(
                "Current Loss",
                f"{latest_loss:.4f}",
                f"{latest_loss - min_loss:+.4f}"
            )
            
        with col2:
            if 'eval_loss' in metrics_df.columns:
                latest_eval = metrics_df['eval_loss'].iloc[-1]
                min_eval = metrics_df['eval_loss'].min()
                st.metric(
                    "Validation Loss",
                    f"{latest_eval:.4f}",
                    f"{latest_eval - min_eval:+.4f}"
                )
                
        with col3:
            current_epoch = metrics_df['epoch'].iloc[-1]
            st.metric("Current Epoch", f"{current_epoch:.2f}")
            
        # Create training plots
        st.subheader("Training Metrics")
        
        # Create subplot with loss and learning rate
        fig = make_subplots(
            rows=2, cols=1,
            subplot_titles=("Loss", "Learning Rate"),
            shared_xaxes=True,
            vertical_spacing=0.1
        )
        
        # Add loss traces
        fig.add_trace(
            go.Scatter(
                x=metrics_df['step'],
                y=metrics_df['loss'],
                name="Training Loss",
                line=dict(color='blue')
            ),
            row=1, col=1
        )
        
        if 'eval_loss' in metrics_df.columns:
            fig.add_trace(
                go.Scatter(
                    x=metrics_df['step'],
                    y=metrics_df['eval_loss'],
                    name="Validation Loss",
                    line=dict(color='red')
                ),
                row=1, col=1
            )
            
        # Add learning rate trace
        fig.add_trace(
            go.Scatter(
                x=metrics_df['step'],
                y=metrics_df['learning_rate'],
                name="Learning Rate",
                line=dict(color='green')
            ),
            row=2, col=1
        )
        
        # Update layout
        fig.update_layout(
            height=600,
            showlegend=True,
            hovermode='x unified'
        )
        
        st.plotly_chart(fig, use_container_width=True)
        
        # Show raw metrics table
        with st.expander("View Raw Metrics"):
            st.dataframe(
                metrics_df.sort_values('step', ascending=False),
                use_container_width=True
            )
