"""Backend component for dataset analysis."""
import json
from pathlib import Path
from typing import Dict, List, Any
import numpy as np
from collections import Counter, defaultdict
import networkx as nx
from transformers import AutoTokenizer
from scripts.utils.path_config import ProjectPaths

class DatasetAnalyzer:
    """Analyzes dataset files and computes statistics."""
    
    def __init__(self):
        """Initialize analyzer with tokenizer."""
        self.tokenizer = AutoTokenizer.from_pretrained(
            "facebook/opt-125m",
            trust_remote_code=True,
            force_download=True
        )
        
    def analyze_datasets(self) -> Dict[str, Any]:
        """Analyze all datasets and return comprehensive statistics."""
        all_examples = []
        file_count = 0
        
        # Load all examples
        for file_path in ProjectPaths.DATASET_DIR.rglob("*.jsonl"):
            file_count += 1
            with open(file_path, 'r') as f:
                for line in f:
                    if line.strip():
                        all_examples.append(json.loads(line))
        
        if not all_examples:
            return {"error": "No examples found"}
            
        # Basic stats
        stats = {
            'total_examples': len(all_examples),
            'total_files': file_count,
            'unique_concepts': len(set(ex['concept'] for ex in all_examples))
        }
        
        # Length distribution
        lengths = [len(ex['explanation'].split()) for ex in all_examples]
        stats['length_distribution'] = lengths
        stats['avg_length'] = np.mean(lengths)
        
        # Concept distribution
        concepts = [ex['concept'] for ex in all_examples]
        stats['concept_distribution'] = dict(Counter(concepts))
        
        # Text content for word cloud
        stats['text_content'] = ' '.join(ex['explanation'] for ex in all_examples)
        
        # Concept hierarchy
        stats['concept_hierarchy'] = self._build_concept_hierarchy(all_examples)
        
        # Cross-references
        stats['cross_references'] = self._find_cross_references(all_examples)
        
        return stats
        
    def compute_quality_metrics(self) -> Dict[str, float]:
        """Compute quality metrics for the datasets."""
        metrics = {}
        all_examples = []
        
        # Load all examples
        for file_path in ProjectPaths.DATASET_DIR.rglob("*.jsonl"):
            with open(file_path, 'r') as f:
                for line in f:
                    if line.strip():
                        all_examples.append(json.loads(line))
                        
        if not all_examples:
            return {"error": "No examples found"}
            
        # Completeness
        required_fields = {'concept', 'explanation', 'examples'}
        complete_count = sum(
            all(field in ex for field in required_fields)
            for ex in all_examples
        )
        metrics['completeness'] = (complete_count / len(all_examples)) * 100
        
        # Consistency
        consistent_count = sum(
            self._check_consistency(ex)
            for ex in all_examples
        )
        metrics['consistency'] = (consistent_count / len(all_examples)) * 100
        
        # Token coverage
        unique_tokens = set()
        total_tokens = 0
        for ex in all_examples:
            tokens = self.tokenizer.tokenize(ex['explanation'])
            unique_tokens.update(tokens)
            total_tokens += len(tokens)
        metrics['token_coverage'] = (len(unique_tokens) / total_tokens) * 100
        metrics['avg_tokens'] = total_tokens / len(all_examples)
        
        # Duplication
        duplicates = self._find_duplicates(all_examples)
        metrics['duplication_rate'] = (len(duplicates) / len(all_examples)) * 100
        
        # Complexity score
        metrics['complexity_score'] = self._compute_complexity(all_examples)
        
        return metrics
        
    def _check_consistency(self, example: Dict) -> bool:
        """Check if an example follows the standard format."""
        # Check basic structure
        if not all(isinstance(example.get(f), str) for f in ['concept', 'explanation']):
            return False
            
        # Check if examples is a list
        if not isinstance(example.get('examples', []), list):
            return False
            
        # Check content guidelines
        if len(example['concept'].split()) > 10:  # Concept should be concise
            return False
            
        if len(example['explanation'].split()) < 10:  # Explanation should be detailed
            return False
            
        return True
        
    def _find_duplicates(self, examples: List[Dict]) -> List[Dict]:
        """Find duplicate or near-duplicate examples."""
        duplicates = []
        seen_concepts = set()
        
        for ex in examples:
            concept = ex['concept'].lower()
            if concept in seen_concepts:
                duplicates.append(ex)
            seen_concepts.add(concept)
            
        return duplicates
        
    def _compute_complexity(self, examples: List[Dict]) -> float:
        """Compute average complexity score (0-10) for examples."""
        scores = []
        
        for ex in examples:
            # Factors affecting complexity:
            # 1. Length of explanation
            # 2. Number of examples
            # 3. Technical terms used
            # 4. Code snippet complexity
            
            explanation_length = len(ex['explanation'].split())
            example_count = len(ex.get('examples', []))
            technical_terms = len([w for w in ex['explanation'].split() 
                                 if w.lower() in {'configuration', 'system', 'package',
                                                'service', 'module', 'function'}])
            
            # Compute score (0-10)
            length_score = min(explanation_length / 100, 4)  # Up to 4 points
            example_score = min(example_count / 2, 3)       # Up to 3 points
            terms_score = min(technical_terms / 5, 3)       # Up to 3 points
            
            total_score = length_score + example_score + terms_score
            scores.append(min(total_score, 10))  # Cap at 10
            
        return np.mean(scores)
        
    def _build_concept_hierarchy(self, examples: List[Dict]) -> Dict:
        """Build a hierarchy of concepts based on relationships."""
        G = nx.DiGraph()
        
        # Add nodes
        for ex in examples:
            G.add_node(ex['concept'])
            
        # Add edges based on references
        for ex in examples:
            explanation = ex['explanation'].lower()
            for other in examples:
                if other['concept'] != ex['concept']:
                    if other['concept'].lower() in explanation:
                        G.add_edge(ex['concept'], other['concept'])
                        
        return nx.to_dict_of_lists(G)
        
    def _find_cross_references(self, examples: List[Dict]) -> List[Dict]:
        """Find concepts that reference each other."""
        references = []
        
        for ex in examples:
            related = []
            explanation = ex['explanation'].lower()
            
            for other in examples:
                if other['concept'] != ex['concept']:
                    if other['concept'].lower() in explanation:
                        related.append(other['concept'])
                        
            if related:
                references.append({
                    'concept': ex['concept'],
                    'references': related
                })
                
        return references
