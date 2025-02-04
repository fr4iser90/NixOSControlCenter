from .base_trainer import NixOSBaseTrainer
import logging
import warnings

logger = logging.getLogger(__name__)

class FeedbackTrainer(NixOSBaseTrainer):
    """Trainer that collects feedback during training for dataset improvement."""
    
    def __init__(self, *args, dataset_manager=None, visualizer=None, **kwargs):
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
        
    def compute_loss(self, model, inputs, return_outputs=False, num_items_in_batch=None):
        """Compute loss and collect feedback."""
        loss, outputs = super().compute_loss(model, inputs, return_outputs=True)
        
        # Save metrics for visualization
        if self.visualizer and hasattr(self.state, 'global_step'):
            metrics = {
                "train_loss": loss.item(),
                "learning_rate": self.optimizer.param_groups[0]["lr"],
                "batch_size": self.args.train_batch_size,
            }
            self.visualizer.save_training_metrics(self.state.global_step, metrics)
        
        # Collect feedback during validation
        if (hasattr(self, 'is_in_eval') and self.is_in_eval and 
            self.state.is_local_process_zero and outputs is not None):
            batch_size = inputs["input_ids"].shape[0]
            for i in range(batch_size):
                # Get decoder for text processing
                decoder = getattr(self, 'processing_class', None) or self.tokenizer
                if decoder is None:
                    logger.warning("No processing_class or tokenizer available for decoding")
                    continue
                    
                try:
                    prediction = decoder.decode(outputs.logits[i].argmax(dim=-1))
                    expected = decoder.decode(inputs["labels"][i])
                    example_id = f"example_{self.state.global_step}_{i}"
                    self._collect_prediction_feedback(prediction, expected, example_id)
                except Exception as e:
                    logger.error(f"Error collecting feedback: {str(e)}")
        
        if return_outputs:
            return loss, outputs
        return loss
    
    def _collect_prediction_feedback(self, prediction, expected, example_id):
        """Collect feedback for a single prediction."""
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
