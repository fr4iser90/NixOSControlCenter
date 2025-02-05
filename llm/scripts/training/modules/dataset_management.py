"""Module for managing dataset loading and preprocessing."""
import json
from pathlib import Path
import logging
from typing import List, Dict, Tuple
from datasets import Dataset

logger = logging.getLogger(__name__)

class DatasetLoader:
    """Handles dataset loading and preprocessing."""
    
    def __init__(self, dataset_manager, dataset_dir: str):
        """Initialize with dataset manager and directory."""
        self.dataset_manager = dataset_manager
        self.dataset_dir = dataset_dir
        
    def load_and_validate_datasets(self) -> Tuple[Dataset, Dataset]:
        """Load, validate and prepare datasets for training."""
        training_data = self._load_concept_datasets()
        
        # Split into train and validation sets
        dataset = Dataset.from_dict(self._format_training_data(training_data))
        dataset = dataset.train_test_split(test_size=0.1)
        
        return dataset["train"], dataset["test"]
        
    def _load_concept_datasets(self) -> List[Dict]:
        """Load and validate concept datasets."""
        training_data = []
        concepts_dir = Path(self.dataset_dir) / 'concepts'
        
        if not concepts_dir.exists():
            logger.warning(f"Concepts directory not found: {concepts_dir}")
            return training_data
            
        for dir_path in concepts_dir.glob('*'):
            if not dir_path.is_dir():
                continue
                
            for jsonl_file in dir_path.glob('*.jsonl'):
                training_data.extend(
                    self._process_jsonl_file(jsonl_file)
                )
                
        return training_data
        
    def _process_jsonl_file(self, jsonl_file: Path) -> List[Dict]:
        """Process a single JSONL file."""
        file_data = []
        rel_path = jsonl_file.relative_to(self.dataset_dir)
        logger.info(f"Loading concept dataset: {rel_path}")
        
        # Validate dataset
        success, error_msg = self.dataset_manager.process_dataset(jsonl_file)
        if not success:
            logger.warning(f"Dataset validation failed for {jsonl_file}: {error_msg}")
            return file_data
            
        # Log dataset status
        status = self.dataset_manager.get_dataset_status(jsonl_file)
        logger.info(f"Dataset metrics: {status['metrics']}")
        
        # Load data
        with open(jsonl_file, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                    file_data.append(data)
                except json.JSONDecodeError as e:
                    logger.error(f"Error parsing line {line_num} in {jsonl_file}: {e}")
                    
        return file_data
        
    def _format_training_data(self, data: List[Dict]) -> Dict:
        """Format raw data into training format."""
        formatted_data = {
            "input_ids": [],
            "labels": [],
            "attention_mask": []
        }
        
        for item in data:
            processed = self.preprocess_example(item)
            for key in formatted_data:
                formatted_data[key].append(processed[key])
                
        return formatted_data
        
    def preprocess_example(self, example: Dict) -> Dict:
        """Preprocess a single training example."""
        # This is a placeholder - actual implementation would depend on
        # your specific preprocessing needs
        return {
            "input_ids": example.get("input_ids", []),
            "labels": example.get("labels", []),
            "attention_mask": example.get("attention_mask", [])
        }
