"""Frontend component for dataset visualization."""
import streamlit as st
import plotly.express as px
import pandas as pd
from typing import Dict
import json
from pathlib import Path
from wordcloud import WordCloud
import matplotlib.pyplot as plt
import networkx as nx
from scripts.utils.path_config import ProjectPaths

class DatasetView:
    """Handles the dataset analysis visualization interface."""
    
    def display_dataset_analysis(self, stats: Dict, quality_metrics: Dict):
        """Display comprehensive dataset analysis."""
        st.title("Dataset Analysis")
        
        # Tabs for different views
        tab1, tab2, tab3 = st.tabs(["Overview", "Explorer", "Analysis"])
        
        with tab1:
            self._display_overview_metrics(stats)
            self._display_distributions(stats)
            self._display_quality_metrics(quality_metrics)
            
        with tab2:
            self._display_dataset_explorer()
            
        with tab3:
            self._display_advanced_analysis(stats)
        
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
            )
            fig = px.bar(concept_df, x='Concept', y='Count')
            st.plotly_chart(fig, use_container_width=True)
            
    def _display_quality_metrics(self, metrics: Dict):
        """Display dataset quality metrics."""
        st.header("Quality Metrics")
        
        # Quality metrics in columns
        cols = st.columns(3)
        with cols[0]:
            st.metric("Completeness", 
                     f"{metrics.get('completeness', 0):.1f}%",
                     help="Percentage of examples with all required fields")
            st.metric("Token Coverage", 
                     f"{metrics.get('token_coverage', 0):.1f}%",
                     help="Percentage of NixOS concepts covered")
                     
        with cols[1]:
            st.metric("Consistency", 
                     f"{metrics.get('consistency', 0):.1f}%",
                     help="Percentage of examples following standard format")
            st.metric("Average Tokens", 
                     metrics.get('avg_tokens', 'N/A'),
                     help="Average number of tokens per example")
                     
        with cols[2]:
            st.metric("Duplication Rate", 
                     f"{metrics.get('duplication_rate', 0):.1f}%",
                     help="Percentage of duplicate or near-duplicate examples")
            st.metric("Complexity Score", 
                     f"{metrics.get('complexity_score', 0):.1f}",
                     help="Average complexity score of examples (0-10)")
                     
    def _display_dataset_explorer(self):
        """Display interactive dataset explorer."""
        st.header("Dataset Explorer")
        
        # Search and filters
        col1, col2 = st.columns([2, 1])
        with col1:
            search_term = st.text_input("Search examples", 
                                      help="Search through concepts and explanations")
        with col2:
            category = st.selectbox("Filter by category",
                                  ["All", "Fundamentals", "Configuration", 
                                   "Package Management", "System Administration"])
        
        # File browser
        st.subheader("Dataset Files")
        dataset_path = ProjectPaths.DATASET_DIR
        
        if dataset_path.exists():
            for file_path in dataset_path.rglob("*.jsonl"):
                rel_path = file_path.relative_to(dataset_path)
                if st.button(f" {rel_path}"):
                    with open(file_path, 'r') as f:
                        data = [json.loads(line) for line in f if line.strip()]
                        df = pd.DataFrame(data)
                        st.dataframe(df)
                        
    def _display_advanced_analysis(self, stats: Dict):
        """Display advanced dataset analysis."""
        st.header("Advanced Analysis")
        
        # Word cloud
        if 'text_content' in stats:
            st.subheader("Common Terms")
            wordcloud = WordCloud(width=800, height=400).generate(stats['text_content'])
            fig, ax = plt.subplots()
            ax.imshow(wordcloud, interpolation='bilinear')
            ax.axis('off')
            st.pyplot(fig)
        
        # Concept hierarchy
        if 'concept_hierarchy' in stats:
            st.subheader("Concept Hierarchy")
            G = nx.DiGraph(stats['concept_hierarchy'])
            fig, ax = plt.subplots(figsize=(10, 10))
            nx.draw(G, with_labels=True, node_color='lightblue', 
                   node_size=1000, font_size=8, ax=ax)
            st.pyplot(fig)
            
        # Cross-references
        if 'cross_references' in stats:
            st.subheader("Concept Cross-References")
            refs_df = pd.DataFrame(stats['cross_references'])
            st.dataframe(refs_df)
