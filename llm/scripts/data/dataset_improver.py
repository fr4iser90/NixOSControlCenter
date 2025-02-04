#!/usr/bin/env python3
import json
from pathlib import Path
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime
import numpy as np
from ..utils.path_config import ProjectPaths
import logging

logger = logging.getLogger(__name__)

@dataclass
class ImprovementSuggestion:
    original_content: dict
    improved_content: dict
    improvement_type: str
    confidence_score: float
    rationale: str
    source_file: Path
    line_number: int

class DatasetImprover:
    def __init__(self):
        self.improvements_dir = ProjectPaths.PROCESSED_DIR / "improvements"
        self.improvements_dir.mkdir(exist_ok=True)
        self.min_confidence_threshold = 0.8

    def analyze_patterns(self, dataset_path: Path) -> Dict[str, Dict]:
        """Analyze patterns in successful examples to guide improvements."""
        patterns = {
            'explanation_length': [],
            'num_examples': [],
            'num_references': [],
            'concept_structure': set(),
            'common_phrases': {}
        }
        
        with open(dataset_path, 'r', encoding='utf-8') as f:
            for line in f:
                data = json.loads(line)
                patterns['explanation_length'].append(len(data['explanation']))
                patterns['num_examples'].append(len(data['examples']))
                patterns['num_references'].append(len(data['references']))
                
                # Extract concept structure (e.g., [Core Concepts], [System Architecture])
                if '[' in data['explanation']:
                    structure = data['explanation'].split(']')[0] + ']'
                    patterns['concept_structure'].add(structure)
                
                # Analyze common phrases in high-quality explanations
                words = data['explanation'].lower().split()
                for i in range(len(words)-1):
                    phrase = f"{words[i]} {words[i+1]}"
                    patterns['common_phrases'][phrase] = patterns['common_phrases'].get(phrase, 0) + 1
        
        # Convert to statistical measures
        patterns['explanation_length'] = {
            'mean': np.mean(patterns['explanation_length']),
            'std': np.std(patterns['explanation_length'])
        }
        patterns['num_examples'] = {
            'mean': np.mean(patterns['num_examples']),
            'std': np.std(patterns['num_examples'])
        }
        patterns['num_references'] = {
            'mean': np.mean(patterns['num_references']),
            'std': np.std(patterns['num_references'])
        }
        
        # Filter common phrases
        patterns['common_phrases'] = {k: v for k, v in patterns['common_phrases'].items() 
                                    if v >= len(patterns['explanation_length']) * 0.1}
        
        return patterns

    def generate_improvements(self, dataset_path: Path, feedback_data: List[Dict]) -> List[ImprovementSuggestion]:
        """Generate improvement suggestions based on patterns and feedback."""
        patterns = self.analyze_patterns(dataset_path)
        improvements = []
        
        with open(dataset_path, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                data = json.loads(line)
                
                # Check against patterns
                exp_len = len(data['explanation'])
                if exp_len < patterns['explanation_length']['mean'] - patterns['explanation_length']['std']:
                    improved = self._enhance_explanation(data, patterns)
                    if improved:
                        improvements.append(ImprovementSuggestion(
                            original_content=data,
                            improved_content=improved,
                            improvement_type='explanation_enhancement',
                            confidence_score=0.85,
                            rationale='Explanation length below average, enhanced with more detail',
                            source_file=dataset_path,
                            line_number=line_num
                        ))
                
                # Check examples
                if len(data['examples']) < patterns['num_examples']['mean']:
                    improved = self._enhance_examples(data, patterns)
                    if improved:
                        improvements.append(ImprovementSuggestion(
                            original_content=data,
                            improved_content=improved,
                            improvement_type='examples_enhancement',
                            confidence_score=0.9,
                            rationale='Added more relevant examples',
                            source_file=dataset_path,
                            line_number=line_num
                        ))
                
                # Check references
                if len(data['references']) < patterns['num_references']['mean']:
                    improved = self._enhance_references(data)
                    if improved:
                        improvements.append(ImprovementSuggestion(
                            original_content=data,
                            improved_content=improved,
                            improvement_type='references_enhancement',
                            confidence_score=0.85,
                            rationale='Added more comprehensive references',
                            source_file=dataset_path,
                            line_number=line_num
                        ))
        
        return improvements

    def _enhance_explanation(self, data: Dict, patterns: Dict) -> Optional[Dict]:
        """Enhance explanation with more detail and structure."""
        explanation = data['explanation']
        
        # Ensure proper structure
        if not any(struct in explanation for struct in patterns['concept_structure']):
            category = self._infer_category(explanation)
            explanation = f"[{category}] {explanation}"
        
        # Enhance with enumeration if not present
        if not any(marker in explanation for marker in ['1)', '2)', '-', '*']):
            points = explanation.split('. ')
            if len(points) > 2:
                explanation = '. '.join([f"{i+1}) {point}" for i, point in enumerate(points)])
        
        if explanation != data['explanation']:
            improved = data.copy()
            improved['explanation'] = explanation
            return improved
        return None

    def _enhance_examples(self, data: Dict, patterns: Dict) -> Optional[Dict]:
        """Add more relevant examples based on the concept."""
        concept_type = data['explanation'].split(']')[0].strip('[')
        
        # Example templates based on concept type
        templates = {
            'Core Concepts': ['Basic usage example', 'Advanced application'],
            'System Architecture': ['Component interaction', 'System flow'],
            'Package Management': ['Package definition', 'Dependency resolution'],
            'Configuration': ['Config snippet', 'Full configuration'],
            'Development': ['Development workflow', 'Build process']
        }
        
        if concept_type in templates and len(data['examples']) < len(templates[concept_type]):
            improved = data.copy()
            improved['examples'] = data['examples'] + [
                template for template in templates[concept_type]
                if template not in data['examples']
            ]
            return improved
        return None

    def _enhance_references(self, data: Dict) -> Optional[Dict]:
        """Add more comprehensive references."""
        concept_type = data['explanation'].split(']')[0].strip('[')
        
        # Standard reference types
        reference_types = {
            'Core Concepts': ['Concept Guide', 'Official Documentation'],
            'System Architecture': ['Architecture Guide', 'Design Documentation'],
            'Package Management': ['Package Guide', 'Nix Manual'],
            'Configuration': ['Configuration Guide', 'Options Reference'],
            'Development': ['Development Guide', 'API Documentation']
        }
        
        if concept_type in reference_types:
            current_refs = set(data['references'])
            suggested_refs = set(reference_types[concept_type])
            if not suggested_refs.issubset(current_refs):
                improved = data.copy()
                improved['references'] = list(current_refs.union(suggested_refs))
                return improved
        return None

    def _infer_category(self, explanation: str) -> str:
        """Infer the concept category from the explanation content."""
        keywords = {
            'Core Concepts': ['basic', 'fundamental', 'principle', 'concept'],
            'System Architecture': ['architecture', 'structure', 'component', 'design'],
            'Package Management': ['package', 'dependency', 'version', 'build'],
            'Configuration': ['config', 'setting', 'option', 'parameter'],
            'Development': ['develop', 'code', 'build', 'compile']
        }
        
        scores = {category: 0 for category in keywords}
        for category, words in keywords.items():
            for word in words:
                if word.lower() in explanation.lower():
                    scores[category] += 1
                    
        return max(scores.items(), key=lambda x: x[1])[0]

    def apply_improvements(self, improvements: List[ImprovementSuggestion]) -> None:
        """Apply improvements to datasets while maintaining original structure."""
        improvements_by_file = {}
        for improvement in improvements:
            if improvement.confidence_score >= self.min_confidence_threshold:
                file_improvements = improvements_by_file.setdefault(improvement.source_file, [])
                file_improvements.append(improvement)
        
        for file_path, file_improvements in improvements_by_file.items():
            # Sort improvements by line number in reverse order
            file_improvements.sort(key=lambda x: x.line_number, reverse=True)
            
            # Read all lines
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            # Apply improvements from bottom to top to maintain line numbers
            for improvement in file_improvements:
                line_idx = improvement.line_number - 1
                if 0 <= line_idx < len(lines):
                    lines[line_idx] = json.dumps(improvement.improved_content) + '\n'
            
            # Write back to file
            improved_path = file_path.parent / f"{file_path.stem}_improved{file_path.suffix}"
            with open(improved_path, 'w', encoding='utf-8') as f:
                f.writelines(lines)
            
            logger.info(f"Applied {len(file_improvements)} improvements to {improved_path}")

    def generate_improvement_report(self, improvements: List[ImprovementSuggestion]) -> str:
        """Generate a detailed report of improvements made."""
        report = ["Dataset Improvement Report", "=" * 25, ""]
        
        by_type = {}
        for imp in improvements:
            by_type.setdefault(imp.improvement_type, []).append(imp)
        
        for imp_type, imps in by_type.items():
            report.append(f"\n{imp_type.replace('_', ' ').title()}")
            report.append("-" * len(imp_type))
            report.append(f"Total improvements: {len(imps)}")
            report.append("Sample improvements:")
            
            for imp in imps[:3]:  # Show first 3 examples
                report.append(f"\n- File: {imp.source_file.name}, Line: {imp.line_number}")
                report.append(f"  Confidence: {imp.confidence_score:.2f}")
                report.append(f"  Rationale: {imp.rationale}")
        
        report_path = self.improvements_dir / f"improvement_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        with open(report_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(report))
        
        return '\n'.join(report)
