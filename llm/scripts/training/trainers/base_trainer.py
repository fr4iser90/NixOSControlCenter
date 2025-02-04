from transformers import Trainer
from ...utils.path_config import ProjectPaths

class NixOSBaseTrainer(Trainer):
    """Base trainer class with common NixOS-specific functionality."""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.best_loss = float('inf')
        self.patience = 3
        self.patience_counter = 0
        
    def compute_loss(self, model, inputs, return_outputs=False, num_items_in_batch=None):
        """Base loss computation with metrics collection."""
        loss, outputs = super().compute_loss(model, inputs, return_outputs=True)
        
        # Collect basic metrics
        metrics = {
            "train_loss": loss.item(),
            "learning_rate": self.optimizer.param_groups[0]["lr"],
            "batch_size": self.args.train_batch_size,
        }
        
        # Add GPU metrics if available
        if torch.cuda.is_available():
            metrics["gpu_memory_used"] = torch.cuda.memory_allocated() / 1024**3
        
        if return_outputs:
            return loss, outputs
        return loss
        
    def save_model(self, output_dir=None):
        """Save model with NixOS-specific handling."""
        if output_dir is None:
            output_dir = ProjectPaths.MODELS_DIR / self.model_name
        super().save_model(output_dir)
        self.save_metrics(output_dir)
