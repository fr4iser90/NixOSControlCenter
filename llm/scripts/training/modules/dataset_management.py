"""Module for managing dataset loading and preprocessing."""
import json
from pathlib import Path
import logging
from typing import List, Dict, Tuple
from datasets import Dataset
from transformers import AutoTokenizer

logger = logging.getLogger(__name__)

class DatasetLoader:
    """Handles dataset loading and preprocessing."""
    
    def __init__(self, dataset_manager, dataset_dir: str):
        """Initialize with dataset manager and directory."""
        self.dataset_manager = dataset_manager
        self.dataset_dir = Path(dataset_dir)
        self.tokenizer = AutoTokenizer.from_pretrained(
            "facebook/opt-125m",
            padding_side="left",
            trust_remote_code=True
        )
        self.tokenizer.pad_token = self.tokenizer.eos_token
        
    def load_and_validate_raw_datasets(self) -> Tuple[Dataset, Dataset]:
        """Process and validate raw datasets before training.
        
        This is a placeholder for future raw data processing.
        Currently not used as we work with pre-processed data.
        """
        raise NotImplementedError(
            "Raw dataset processing not implemented. "
            "Use load_and_validate_processed_datasets() instead for pre-processed data."
        )
        
    def load_and_validate_processed_datasets(self) -> Tuple[Dataset, Dataset]:
        """Load and validate already processed datasets for training."""
        all_data = []
        jsonl_files = list(self.dataset_dir.rglob("*.jsonl"))
        
        if not jsonl_files:
            raise ValueError(f"No JSONL files found in {self.dataset_dir}")
            
        logger.info(f"Loading {len(jsonl_files)} datasets for training")
        
        for jsonl_file in jsonl_files:
            logger.info(f"Loading dataset: {jsonl_file.relative_to(self.dataset_dir)}")
            with open(jsonl_file, 'r', encoding='utf-8') as f:
                for line in f:
                    if line.strip():
                        all_data.append(json.loads(line))
        
        return self._prepare_datasets(all_data)
        
    def load_test_dataset(self) -> Tuple[Dataset, Dataset]:
        """Load a single dataset for testing purposes.
        
        Uses only the core concepts dataset for quick testing and validation.
        """
        logger.info("Test mode: Loading only core concepts dataset")
        test_file = Path(self.dataset_dir).parent / "00_fundamentals/01_core_concepts.jsonl"
        
        if not test_file.exists():
            raise ValueError(f"Test file not found: {test_file}")
            
        all_data = []
        with open(test_file, 'r', encoding='utf-8') as f:
            for line in f:
                if line.strip():
                    all_data.append(json.loads(line))
                    
        return self._prepare_datasets(all_data)
        
    def _prepare_datasets(self, all_data: List[Dict]) -> Tuple[Dataset, Dataset]:
        """Prepare and tokenize datasets from loaded data."""
        logger.info(f"Total examples loaded: {len(all_data)}")
        
        # Split into train/eval
        total_examples = len(all_data)
        split_idx = int(total_examples * 0.9)  # 90% train, 10% eval
        
        train_data = all_data[:split_idx]
        eval_data = all_data[split_idx:]
        
        logger.info(f"Train examples: {len(train_data)}, Eval examples: {len(eval_data)}")
        
        # Convert to datasets
        train_texts = [f"{item['concept']}\n{item['explanation']}" for item in train_data]
        eval_texts = [f"{item['concept']}\n{item['explanation']}" for item in eval_data]
        
        train_dataset = Dataset.from_dict({'text': train_texts})
        eval_dataset = Dataset.from_dict({'text': eval_texts})
        
        # Tokenize
        train_tokenized = train_dataset.map(
            self._tokenize_function,
            batched=True,
            remove_columns=train_dataset.column_names
        )
        
        eval_tokenized = eval_dataset.map(
            self._tokenize_function,
            batched=True,
            remove_columns=eval_dataset.column_names
        )
        
        return train_tokenized, eval_tokenized
        
    def _tokenize_function(self, examples):
        """Tokenize a batch of examples."""
        model_inputs = self.tokenizer(
            examples['text'],
            max_length=512,
            padding="max_length",
            truncation=True,
            return_tensors="pt"
        )
        
        # Create the labels (same as input_ids for causal language modeling)
        model_inputs["labels"] = model_inputs["input_ids"].clone()
        
        return model_inputs
