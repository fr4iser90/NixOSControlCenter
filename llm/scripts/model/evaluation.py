#!/usr/bin/env python3
"""Module for model evaluation and interpretation."""
import logging
from pathlib import Path
from typing import Dict, Optional, Any

from ..training.train_model import ModelTrainer
from ..training.modules.model_interpretation import ModelInterpreter

logger = logging.getLogger(__name__)

class ModelEvaluator:
    """Handles model evaluation and interpretation."""
    
    def __init__(self, models_dir: Path):
        """Initialize with models directory."""
        self.models_dir = models_dir
        
    def evaluate_model(
        self,
        model_name: str,
        test_dataset: Optional[str] = None,
        checkpoint: Optional[Path] = None
    ) -> Dict[str, Any]:
        """Evaluate model performance with detailed metrics."""
        model_path = checkpoint if checkpoint else self.models_dir / model_name
        
        trainer = ModelTrainer(
            model_name_or_path=model_path,
            test_mode=True
        )
        
        try:
            trainer.setup()
            results = trainer.evaluate(test_dataset)
            self._save_evaluation_results(model_name, results)
            return results
        except Exception as e:
            logger.error(f"Error during evaluation: {e}")
            return {}
            
    def explain_prediction(
        self,
        model_name: str,
        text: str,
        checkpoint: Optional[Path] = None
    ) -> Dict[str, Any]:
        """Generate model interpretation for a prediction."""
        model_path = checkpoint if checkpoint else self.models_dir / model_name
        
        trainer = ModelTrainer(
            model_name_or_path=model_path,
            test_mode=True
        )
        
        try:
            trainer.setup()
            interpreter = ModelInterpreter(trainer.model, trainer.tokenizer)
            return interpreter.explain_prediction(text)
        except Exception as e:
            logger.error(f"Error during prediction interpretation: {e}")
            return {}
            
    def _save_evaluation_results(self, model_name: str, results: Dict):
        """Save evaluation results."""
        results_file = self.models_dir / model_name / 'evaluation_results.json'
        with open(results_file, 'w') as f:
            json.dump(results, f, indent=2)
