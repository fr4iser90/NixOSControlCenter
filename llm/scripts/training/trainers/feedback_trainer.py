#!/usr/bin/env python3
"""Trainer for feedback-based model training."""
from .base_trainer import NixOSBaseTrainer
from transformers import TrainerCallback
import logging
import warnings
import torch

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class MetricsCallback(TrainerCallback):
    """Callback to handle training metrics visualization."""
    
    def __init__(self, trainer):
        self.trainer = trainer
        self.metrics_manager = None
        
    def on_init_end(self, args, state, control, **kwargs):
        """Called when trainer initialization ends."""
        from ...visualization.backend.metrics_manager import MetricsManager
        self.metrics_manager = MetricsManager()
        return control
        
    def on_log(self, args, state, control, logs=None, **kwargs):
        """Called when trainer logs metrics."""
        if not logs:
            return control
            
        # Save training metrics
        metrics = {
            'loss': logs.get('loss', 0),
            'learning_rate': logs.get('learning_rate', 0),
            'epoch': logs.get('epoch', 0)
        }
        
        if 'eval_loss' in logs:
            metrics['eval_loss'] = logs['eval_loss']
            
        self.metrics_manager.save_training_metrics(
            step=state.global_step,
            metrics=metrics
        )
        return control

class FeedbackTrainer(NixOSBaseTrainer):
    """Trainer that collects feedback during training for dataset improvement."""
    
    def __init__(self, *args, dataset_manager=None, visualizer=None, **kwargs):
        """Initialize feedback trainer."""
        logger.info("Initializing feedback trainer")
        # Add metrics callback if visualization is enabled
        if visualizer:
            callbacks = kwargs.get('callbacks', [])
            callbacks.append(MetricsCallback(self))
            kwargs['callbacks'] = callbacks
            
        super().__init__(*args, **kwargs)
        self.dataset_manager = dataset_manager
        self.visualizer = visualizer
        
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
            
    def evaluate(self, *args, **kwargs):
        """Evaluate model with feedback metrics."""
        try:
            logger.info("Starting feedback evaluation")
            result = super().evaluate(*args, **kwargs)
            logger.info("Feedback evaluation completed successfully")
            return result
        except Exception as e:
            logger.error(f"Error in feedback evaluation: {e}")
            raise
            
    def compute_loss(self, model, inputs, return_outputs=False, num_items_in_batch=None):
        """Compute loss and collect feedback."""
        try:
            logger.debug("Computing loss with feedback")
            loss, outputs = super().compute_loss(model, inputs, return_outputs=True)
            
            # Collect feedback during validation
            if (hasattr(self, 'is_in_eval') and self.is_in_eval and 
                self.state.is_local_process_zero and outputs is not None):
                batch_size = inputs["input_ids"].shape[0]
                for i in range(batch_size):
                    try:
                        # Get decoder for text processing
                        decoder = getattr(self, 'processing_class', None) or self.tokenizer
                        if decoder is None:
                            logger.warning("No processing_class or tokenizer available for decoding")
                            continue
                        
                        # Process prediction and expected output
                        prediction = decoder.decode(outputs.logits[i].argmax(dim=-1))
                        expected = decoder.decode(inputs["labels"][i])
                        example_id = inputs.get("example_ids", [None])[i]
                        
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
        if self.dataset_manager:
            feedback = {
                'example_id': example_id,
                'prediction': prediction,
                'expected': expected,
                'score': self._compute_prediction_score(prediction, expected)
            }
            self.dataset_manager.add_feedback(feedback)
            
    def _compute_prediction_score(self, prediction, expected):
        """Compute a similarity score between prediction and expected output."""
        # Simple exact match score for now
        return 1.0 if prediction.strip() == expected.strip() else 0.0
        
    def evaluation_loop(self, *args, **kwargs):
        """Override evaluation loop to track when we're in evaluation."""
        self.is_in_eval = True
        results = super().evaluation_loop(*args, **kwargs)
        self.is_in_eval = False
        return results
