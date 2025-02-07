#!/usr/bin/env python3
"""Base trainer class with common NixOS-specific functionality."""
import logging
from transformers import Trainer, DataCollatorForLanguageModeling
import torch
from ...utils.path_config import ProjectPaths
import warnings

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class NixOSBaseTrainer(Trainer):
    """Base trainer class with common NixOS-specific functionality."""
    
    def __init__(self, *args, **kwargs):
        """Initialize trainer with NixOS-specific settings."""
        if 'tokenizer' in kwargs:
            # Create data collator with tokenizer
            kwargs['data_collator'] = DataCollatorForLanguageModeling(
                tokenizer=kwargs['tokenizer'],
                mlm=False
            )
            # Store tokenizer as processing class
            kwargs['processing_class'] = kwargs.pop('tokenizer')
            
        super().__init__(*args, **kwargs)
        
        # Handle tokenizer deprecation
        if hasattr(self, 'tokenizer') and not hasattr(self, 'processing_class'):
            self.processing_class = self.tokenizer
            warnings.warn(
                "Using tokenizer as processing_class. This is deprecated and will be removed in a future version.",
                DeprecationWarning
            )
            
        self.best_loss = float('inf')
        self.patience = 3
        self.patience_counter = 0
        
    def get_decoder(self):
        """Get the appropriate decoder for text processing."""
        decoder = getattr(self, 'processing_class', None)
        if decoder is None:
            decoder = getattr(self, 'tokenizer', None)
            if decoder is not None:
                warnings.warn(
                    "Using tokenizer for decoding. This is deprecated and will be removed in a future version.",
                    DeprecationWarning
                )
        return decoder
        
    def decode_text(self, token_ids):
        """Safely decode token IDs to text."""
        decoder = self.get_decoder()
        if decoder is None:
            logger.error("No decoder (processing_class or tokenizer) found")
            return ""
        return decoder.decode(token_ids, skip_special_tokens=True)
        
    def save_checkpoints(self):
        """Save model checkpoints."""
        try:
            self.save_model()
            logger.info(f"Model saved to {self.args.output_dir}")
        except Exception as e:
            logger.error(f"Error saving model: {e}")
            raise
            
    def train(self, *args, **kwargs):
        """Train the model with error handling."""
        try:
            logger.info("Starting training...")
            result = super().train(*args, **kwargs)
            logger.info("Training completed successfully")
            return result
        except Exception as e:
            logger.error(f"Training error: {e}")
            raise
            
    def evaluate(self, *args, **kwargs):
        """Evaluate the model with error handling."""
        try:
            logger.info("Starting evaluation...")
            result = super().evaluate(*args, **kwargs)
            logger.info("Evaluation completed successfully")
            return result
        except Exception as e:
            logger.error(f"Evaluation error: {e}")
            raise
            
    def compute_loss(self, model, inputs, return_outputs=False, num_items_in_batch=None):
        """Base loss computation."""
        try:
            if "labels" in inputs:
                labels = inputs["labels"]
            else:
                labels = inputs["input_ids"]
                
            outputs = model(**inputs)
            logits = outputs.logits
            
            # Shift logits and labels for causal language modeling
            shift_logits = logits[..., :-1, :].contiguous()
            shift_labels = labels[..., 1:].contiguous()
            
            loss_fct = torch.nn.CrossEntropyLoss()
            loss = loss_fct(shift_logits.view(-1, shift_logits.size(-1)), shift_labels.view(-1))
            
            if return_outputs:
                return loss, outputs
            return loss
            
        except Exception as e:
            logger.error(f"Error computing loss: {str(e)}")
            if return_outputs:
                return torch.tensor(0.0), None
            return torch.tensor(0.0)
        
    def save_model(self, output_dir=None, _internal_call=False):
        """Save model with NixOS-specific handling."""
        try:
            if output_dir is None:
                output_dir = self.args.output_dir
                
            # Save model and configuration
            self.model.save_pretrained(output_dir)
            if self.processing_class:
                self.processing_class.save_pretrained(output_dir)
            elif self.tokenizer:
                self.tokenizer.save_pretrained(output_dir)
                
            # Save training arguments
            torch.save(self.args, str(ProjectPaths.MODELS_DIR / "training_args.bin"))
            logger.info(f"Model saved successfully to {output_dir}")
            
        except Exception as e:
            logger.error(f"Error saving model: {e}")
            raise
