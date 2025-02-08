#!/usr/bin/env python3
"""Trainer for feedback-based model training."""
from .base_trainer import NixOSBaseTrainer
from transformers import TrainerCallback
import logging
import warnings
import torch
from typing import Dict
from ...visualization.backend.metrics_manager import MetricsManager
from ...utils.path_config import ProjectPaths

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class MetricsCallback(TrainerCallback):
    """Callback to handle training metrics visualization."""
    
    def __init__(self):
        """Initialize metrics callback."""
        super().__init__()
        self.paths_config = ProjectPaths()
        self.metrics_manager = MetricsManager(self.paths_config)
        
    def on_init_end(self, args, state, control, **kwargs):
        """Called when trainer initialization ends."""
        # Ensure metrics directory exists
        self.paths_config.METRICS_DIR.mkdir(parents=True, exist_ok=True)
        return control
        
    def on_log(self, args, state, control, logs=None, **kwargs):
        """Called when trainer logs metrics."""
        if not logs:
            return control
            
        # Save training metrics
        try:
            if self.metrics_manager is None:
                self.metrics_manager = MetricsManager(self.paths_config)
            self.metrics_manager.save_training_metrics(state.global_step, logs)
        except Exception as e:
            logger.error(f"Failed to log metrics: {e}")
            # Try to recreate metrics manager if it failed
            try:
                self.metrics_manager = MetricsManager(self.paths_config)
            except Exception as e2:
                logger.error(f"Failed to recreate metrics manager: {e2}")
        return control

class FeedbackTrainer(NixOSBaseTrainer):
    """Trainer that collects feedback during training for dataset improvement."""
    
    def __init__(self, model_name: str, model=None, tokenizer=None, dataset_manager=None, *args, **kwargs):
        """Initialize feedback trainer.
        
        Args:
            model_name: Name or path of the model
            model: Optional model instance
            tokenizer: Optional tokenizer instance
            dataset_manager: Optional dataset manager instance
            *args: Additional positional arguments
            **kwargs: Additional keyword arguments
        """
        logger.info("Initializing feedback trainer")
        
        # Initialize feedback collection
        self.feedback_data = []
        self.feedback_scores = []
        self.dataset_manager = dataset_manager
        self.dataset_path = kwargs.pop('dataset_path', None)
        
        # Create metrics callback
        self.metrics_callback = MetricsCallback()
        
        # Remove our args from kwargs
        kwargs.pop('model', None)
        kwargs.pop('tokenizer', None)
        kwargs.pop('dataset_manager', None)
        
        # Initialize parent class
        super().__init__(
            model_name=model_name,
            model=model,
            tokenizer=tokenizer,
            dataset_manager=dataset_manager,
            *args,
            **kwargs
        )

        # Add metrics callback
        self.trainer.add_callback(self.metrics_callback)

        # Handle tokenizer deprecation
        if hasattr(self, 'tokenizer') and not hasattr(self, 'processing_class'):
            self.processing_class = self.tokenizer
            warnings.warn(
                "Using tokenizer as processing_class. This is deprecated and will be removed in a future version.",
                DeprecationWarning
            )
        
    def train(self, *args, **kwargs):
        """Train model with feedback loop."""
        try:
            logger.info("Starting feedback training loop")
            result = super().train(*args, **kwargs)
            logger.info("Feedback training completed successfully")
            return result
        except Exception as e:
            logger.error(f"Error in feedback training: {e}")
            raise
            
    def evaluate(self, *args, **kwargs) -> Dict[str, float]:
        """Evaluate model with feedback metrics.
        
        Returns:
            Dict containing evaluation metrics
        """
        try:
            logger.info("Starting feedback evaluation")
            result = super().evaluate(*args, **kwargs)
            
            # Add feedback metrics
            feedback_metrics = {
                'avg_feedback_score': sum(self.feedback_scores) / len(self.feedback_scores) if self.feedback_scores else 0,
                'total_feedback': len(self.feedback_data)
            }
            result.update(feedback_metrics)
            
            return result
        except Exception as e:
            logger.error(f"Error in feedback evaluation: {e}")
            raise
            
    def compute_loss(self, model, inputs, return_outputs=False, num_items_in_batch=None):
        """Compute loss and collect feedback."""
        try:
            # Get outputs from model
            outputs = model(**inputs)
            loss = outputs.loss
            
            # Only collect feedback during evaluation
            if hasattr(self, '_in_evaluation') and self._in_evaluation:
                batch_size = inputs["input_ids"].shape[0]
                decoder = getattr(self, 'processing_class', None) or getattr(self, 'tokenizer', None)
                
                # Process each item in batch
                for i in range(batch_size):
                    try:
                        if not decoder:
                            logger.warning("No processing_class or tokenizer available for decoding")
                            continue
                        
                        # Get example ID from dataset if available
                        example_id = str(i)  # Default to index as ID
                        try:
                            if hasattr(self.eval_dataset, 'data'):
                                dataset_index = self.eval_dataset.current_index + i if hasattr(self.eval_dataset, 'current_index') else i
                                if dataset_index < len(self.eval_dataset.data):
                                    if 'id' in self.eval_dataset.data[dataset_index]:
                                        example_id = str(self.eval_dataset.data[dataset_index]['id'])
                        except (AttributeError, IndexError) as e:
                            logger.debug(f"Could not get example ID from dataset: {e}")
                        
                        # Process prediction and expected output
                        prediction = decoder.decode(outputs.logits[i].argmax(dim=-1))
                        expected = decoder.decode(inputs["labels"][i])
                        
                        # Collect feedback for this prediction
                        self._collect_prediction_feedback(prediction, expected, example_id)
                    except Exception as e:
                        logger.error(f"Error processing prediction {i}: {e}")
                        continue
            
            if return_outputs:
                return loss, outputs
            return loss
            
        except Exception as e:
            logger.error(f"Error in compute_loss: {e}")
            raise
    
    def _collect_prediction_feedback(self, prediction, expected, example_id):
        """Collect feedback about model predictions."""
        from ...data.dataset_manager import DatasetFeedback
        from datetime import datetime
        
        # Create feedback object
        feedback = {
            'example_id': str(example_id) if example_id else 'unknown',
            'prediction': prediction.strip(),
            'expected': expected.strip(),
            'score': self._compute_prediction_score(prediction, expected),
            'improvement_suggestions': [],
            'timestamp': datetime.now().isoformat()
        }
        
        # Store feedback locally
        self.feedback_data.append(feedback)
        self.feedback_scores.append(feedback['score'])
        
        # Add to dataset manager if available
        if self.dataset_manager and self.dataset_path:
            try:
                dataset_feedback = DatasetFeedback(**feedback)
                self.dataset_manager.add_feedback(self.dataset_path, dataset_feedback)
            except Exception as e:
                logger.error(f"Error adding feedback to dataset manager: {e}")
                
    def _compute_prediction_score(self, prediction, expected):
        """Compute a similarity score between prediction and expected output."""
        # Simple exact match score for now
        return 1.0 if prediction.strip() == expected.strip() else 0.0
        
    def evaluation_loop(self, *args, **kwargs):
        """Override evaluation loop to track when we're in evaluation."""
        self._in_evaluation = True
        results = super().evaluation_loop(*args, **kwargs)
        self._in_evaluation = False
        return results
