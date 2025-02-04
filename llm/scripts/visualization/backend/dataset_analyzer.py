"""Backend service for dataset analysis."""
import json
import numpy as np
from pathlib import Path
from typing import Dict, List
from ..utils.path_utils import ProjectPaths

class DatasetAnalyzer:
    """Analyzes dataset statistics and quality metrics."""
    
    def get_dataset_stats(self) -> Dict:
        """Get comprehensive dataset statistics."""
        stats = {}
        dataset_path = ProjectPaths.DATA_DIR
        
        try:
            # Basic stats
            files = list(dataset_path.rglob('*.jsonl'))
            stats['total_files'] = len(files)
            
            # Detailed analysis
            lengths = []
            concepts = set()
            total_examples = 0
            concept_counts = {}
            
            for file in files:
                with open(file) as f:
                    for line in f:
                        try:
                            data = json.loads(line)
                            length = len(data.get('text', ''))
                            lengths.append(length)
                            concepts.update(data.get('concepts', []))
                            total_examples += 1
                            
                            # Update concept distribution
                            for concept in data.get('concepts', []):
                                concept_counts[concept] = concept_counts.get(concept, 0) + 1
                        except:
                            continue
            
            stats.update({
                'total_examples': total_examples,
                'avg_length': np.mean(lengths) if lengths else 0,
                'unique_concepts': len(concepts),
                'length_distribution': lengths,
                'concept_distribution': concept_counts
            })
            
        except Exception as e:
            stats['error'] = str(e)
            
        return stats
        
    def get_quality_metrics(self) -> Dict:
        """Calculate dataset quality metrics."""
        metrics = {
            'completeness': 0,
            'consistency': 0,
            'concept_coverage': 0
        }
        
        try:
            dataset_path = ProjectPaths.DATA_DIR
            total_examples = 0
            complete_examples = 0
            consistent_examples = 0
            concept_examples = 0
            
            for file in dataset_path.rglob('*.jsonl'):
                with open(file) as f:
                    for line in f:
                        try:
                            data = json.loads(line)
                            total_examples += 1
                            
                            if all(k in data for k in ['text', 'concepts']):
                                complete_examples += 1
                                
                            if data.get('text') and data.get('concepts'):
                                consistent_examples += 1
                                
                            if data.get('concepts'):
                                concept_examples += 1
                                
                        except:
                            continue
            
            if total_examples > 0:
                metrics.update({
                    'completeness': complete_examples / total_examples,
                    'consistency': consistent_examples / total_examples,
                    'concept_coverage': concept_examples / total_examples
                })
                
        except Exception as e:
            metrics['error'] = str(e)
            
        return metrics
