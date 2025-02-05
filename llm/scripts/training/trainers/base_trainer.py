from transformers import Trainer, DataCollatorForLanguageModeling
import torch
from ...utils.path_config import ProjectPaths
import warnings
import logging

logger = logging.getLogger(__name__)

class NixOSBaseTrainer(Trainer):
    """Base trainer class with common NixOS-specific functionality."""
    
    def __init__(self, *args, **kwargs):
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
            logger.error("No decoder (processing_class or tokenizer) available")
            return None
        try:
            return decoder.decode(token_ids)
        except Exception as e:
            logger.error(f"Error decoding text: {str(e)}")
            return None
            
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
        if output_dir is None:
            output_dir = self.args.output_dir
            
        # Save model and configuration
        self.model.save_pretrained(output_dir)
        if self.processing_class:
            self.processing_class.save_pretrained(output_dir)
        elif self.tokenizer:
            self.tokenizer.save_pretrained(output_dir)
            
        # Save training arguments
        torch.save(self.args, str(ProjectPaths.MODEL_DIR / "training_args.bin"))
