"""Frontend component for dataset visualization."""
import streamlit as st
import plotly.express as px
import pandas as pd
from typing import Dict

class DatasetView:
    """Handles the dataset analysis visualization interface."""
    
    def display_dataset_analysis(self, stats: Dict, quality_metrics: Dict):
        """Display comprehensive dataset analysis."""
        st.title("Dataset Analysis")
        
        self._display_overview_metrics(stats)
        self._display_distributions(stats)
        self._display_quality_metrics(quality_metrics)
        
    def _display_overview_metrics(self, stats: Dict):
        """Display key dataset metrics."""
        st.header("Dataset Overview")
        cols = st.columns(4)
        
        with cols[0]:
            st.metric("Total Examples", stats.get('total_examples', 'N/A'))
        with cols[1]:
            st.metric("Total Files", stats.get('total_files', 'N/A'))
        with cols[2]:
            st.metric("Average Length", 
                     f"{stats.get('avg_length', 0):.1f}")
        with cols[3]:
            st.metric("Unique Concepts", 
                     stats.get('unique_concepts', 'N/A'))
    
    def _display_distributions(self, stats: Dict):
        """Display dataset distributions."""
        # Length Distribution
        if 'length_distribution' in stats:
            st.subheader("Length Distribution")
            fig = px.histogram(
                x=stats['length_distribution'],
                nbins=50,
                title="Distribution of Example Lengths"
            )
            st.plotly_chart(fig, use_container_width=True)
        
        # Concept Distribution
        if 'concept_distribution' in stats:
            st.subheader("Concept Distribution")
            concept_df = pd.DataFrame(
                stats['concept_distribution'].items(),
                columns=['Concept', 'Count']
            ).sort_values('Count', ascending=False)
            
            fig = px.bar(
                concept_df.head(20),
                x='Concept',
                y='Count',
                title="Top 20 Concepts"
            )
            st.plotly_chart(fig, use_container_width=True)
            
            with st.expander("View All Concepts"):
                st.dataframe(concept_df)
    
    def _display_quality_metrics(self, metrics: Dict):
        """Display dataset quality metrics."""
        st.header("Quality Metrics")
        
        cols = st.columns(3)
        with cols[0]:
            st.metric("Completeness", 
                     f"{metrics.get('completeness', 0):.1%}")
        with cols[1]:
            st.metric("Consistency", 
                     f"{metrics.get('consistency', 0):.1%}")
        with cols[2]:
            st.metric("Concept Coverage", 
                     f"{metrics.get('concept_coverage', 0):.1%}")
        
        if 'error' in metrics:
            st.error(f"Error in quality metrics: {metrics['error']}")
            
        # Quality insights
        self._display_quality_insights(metrics)
