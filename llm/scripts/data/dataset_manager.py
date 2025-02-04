#!/usr/bin/env python3
import json
import logging
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union
from dataclasses import dataclass, asdict
import hashlib
from datetime import datetime
from ..utils.path_config import ProjectPaths

@dataclass
class DatasetMetrics:
    total_examples: int
    avg_prompt_length: float
    avg_response_length: float
    concept_coverage: Dict[str, int]
    quality_score: float
    last_validation: str
    hash: str

@dataclass
class DatasetFeedback:
    example_id: str
    prediction: str
    expected: str
    score: float
    improvement_suggestions: List[str]
    timestamp: str

class DatasetValidator:
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.metrics_dir = ProjectPaths.PROCESSED_DIR / "metrics"
        self.feedback_dir = ProjectPaths.PROCESSED_DIR / "feedback"
        self.metrics_dir.mkdir(exist_ok=True)
        self.feedback_dir.mkdir(exist_ok=True)

    def validate_jsonl(self, file_path: Path) -> Tuple[bool, List[str]]:
        """Validate JSONL file format and content structure."""
        errors = []
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                for i, line in enumerate(f, 1):
                    try:
                        data = json.loads(line.strip())
                        # Validate required fields
                        required_fields = ['concept', 'explanation', 'examples', 'references']
                        for field in required_fields:
                            if field not in data:
                                errors.append(f"Line {i}: Missing required field '{field}'")
                            elif not data[field]:
                                errors.append(f"Line {i}: Empty field '{field}'")
                        
                        # Validate content quality
                        if len(data['explanation']) < 50:
                            errors.append(f"Line {i}: Explanation too short (< 50 chars)")
                        if not isinstance(data['examples'], list):
                            errors.append(f"Line {i}: 'examples' must be a list")
                        if not isinstance(data['references'], list):
                            errors.append(f"Line {i}: 'references' must be a list")
                            
                    except json.JSONDecodeError as e:
                        errors.append(f"Line {i}: Invalid JSON - {str(e)}")
                    except Exception as e:
                        errors.append(f"Line {i}: Validation error - {str(e)}")
                        
        except Exception as e:
            errors.append(f"File error: {str(e)}")
            
        return len(errors) == 0, errors

    def compute_metrics(self, dataset_path: Path) -> DatasetMetrics:
        """Compute and store dataset metrics."""
        total_examples = 0
        total_prompt_len = 0
        total_response_len = 0
        concepts = {}
        quality_score = 0
        
        with open(dataset_path, 'r', encoding='utf-8') as f:
            content = f.read()
            file_hash = hashlib.sha256(content.encode()).hexdigest()
            
            for line in content.splitlines():
                if not line.strip():
                    continue
                    
                data = json.loads(line)
                total_examples += 1
                total_prompt_len += len(data['concept'])
                total_response_len += len(data['explanation'])
                
                # Track concept coverage
                concept_type = data['explanation'].split(']')[0].strip('[')
                concepts[concept_type] = concepts.get(concept_type, 0) + 1
                
                # Calculate quality score
                has_examples = len(data['examples']) > 0
                has_references = len(data['references']) > 0
                explanation_quality = len(data['explanation']) >= 100
                quality_score += (has_examples + has_references + explanation_quality) / 3
        
        avg_quality = quality_score / total_examples if total_examples > 0 else 0
        
        return DatasetMetrics(
            total_examples=total_examples,
            avg_prompt_length=total_prompt_len / total_examples if total_examples > 0 else 0,
            avg_response_length=total_response_len / total_examples if total_examples > 0 else 0,
            concept_coverage=concepts,
            quality_score=avg_quality,
            last_validation=datetime.now().isoformat(),
            hash=file_hash
        )

    def save_metrics(self, dataset_path: Path, metrics: DatasetMetrics):
        """Save metrics to JSON file."""
        metrics_file = self.metrics_dir / f"{dataset_path.stem}_metrics.json"
        with open(metrics_file, 'w', encoding='utf-8') as f:
            json.dump(asdict(metrics), f, indent=2)

    def save_feedback(self, dataset_path: Path, feedback: DatasetFeedback):
        """Save model feedback for dataset improvement."""
        feedback_file = self.feedback_dir / f"{dataset_path.stem}_feedback.jsonl"
        with open(feedback_file, 'a', encoding='utf-8') as f:
            f.write(json.dumps(asdict(feedback)) + '\n')

    def analyze_feedback(self, dataset_path: Path) -> Dict[str, Union[int, float, List[str]]]:
        """Analyze collected feedback for a dataset."""
        feedback_file = self.feedback_dir / f"{dataset_path.stem}_feedback.jsonl"
        if not feedback_file.exists():
            return {"total_feedback": 0, "avg_score": 0.0, "improvement_areas": []}
            
        total_score = 0
        improvement_areas = {}
        feedback_count = 0
        
        with open(feedback_file, 'r', encoding='utf-8') as f:
            for line in f:
                feedback = json.loads(line)
                total_score += feedback['score']
                feedback_count += 1
                for suggestion in feedback['improvement_suggestions']:
                    improvement_areas[suggestion] = improvement_areas.get(suggestion, 0) + 1
                    
        return {
            "total_feedback": feedback_count,
            "avg_score": total_score / feedback_count if feedback_count > 0 else 0.0,
            "improvement_areas": sorted(
                improvement_areas.items(),
                key=lambda x: x[1],
                reverse=True
            )
        }

class DatasetManager:
    def __init__(self):
        self.validator = DatasetValidator()
        self.logger = logging.getLogger(__name__)

    def process_dataset(self, dataset_path: Path) -> Tuple[bool, Optional[str]]:
        """Process and validate a dataset file."""
        # Validate JSONL format and content
        is_valid, errors = self.validator.validate_jsonl(dataset_path)
        if not is_valid:
            error_msg = "\n".join(errors)
            self.logger.error(f"Dataset validation failed for {dataset_path}:\n{error_msg}")
            return False, error_msg

        # Compute and save metrics
        try:
            metrics = self.validator.compute_metrics(dataset_path)
            self.validator.save_metrics(dataset_path, metrics)
            self.logger.info(f"Processed dataset {dataset_path} - {metrics.total_examples} examples")
            return True, None
        except Exception as e:
            error_msg = f"Error processing dataset: {str(e)}"
            self.logger.error(error_msg)
            return False, error_msg

    def add_feedback(self, dataset_path: Path, feedback: DatasetFeedback):
        """Add model feedback for dataset improvement."""
        self.validator.save_feedback(dataset_path, feedback)

    def get_dataset_status(self, dataset_path: Path) -> Dict[str, Union[DatasetMetrics, Dict]]:
        """Get comprehensive dataset status including metrics and feedback analysis."""
        metrics_file = self.validator.metrics_dir / f"{dataset_path.stem}_metrics.json"
        
        if not metrics_file.exists():
            self.process_dataset(dataset_path)
            
        with open(metrics_file, 'r', encoding='utf-8') as f:
            metrics = DatasetMetrics(**json.load(f))
            
        feedback_analysis = self.validator.analyze_feedback(dataset_path)
        
        return {
            "metrics": metrics,
            "feedback_analysis": feedback_analysis
        }
