import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import LoraConfig, get_peft_model
from .feedback_trainer import FeedbackTrainer

class LoRATrainer(FeedbackTrainer):
    """Trainer specifically for LoRA-based model fine-tuning."""
    
    def __init__(self, model_name="NixOS", *args, **kwargs):
        # Setup model and tokenizer
        self.model_name = model_name
        self.setup_model()
        
        # Initialize parent class with our model and tokenizer
        kwargs['model'] = self.model
        kwargs['tokenizer'] = self.tokenizer
        super().__init__(*args, **kwargs)
        
    def setup_model(self):
        """Initialize the model with LoRA configuration."""
        # Setup tokenizer
        self.tokenizer = AutoTokenizer.from_pretrained(
            "facebook/opt-125m",
            padding_side="left",
            trust_remote_code=True
        )
        self.tokenizer.pad_token = self.tokenizer.eos_token
        
        # Load base model
        base_model = AutoModelForCausalLM.from_pretrained(
            "facebook/opt-125m",
            torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
            device_map="auto",
            low_cpu_mem_usage=True
        )
        base_model.config.pad_token_id = self.tokenizer.eos_token_id
        base_model.config.use_cache = False  # Required for gradient checkpointing
        
        # Enable gradient checkpointing
        base_model.gradient_checkpointing_enable()
        
        # Apply LoRA config
        lora_config = LoraConfig(
            r=8,
            lora_alpha=32,
            target_modules=["q_proj", "v_proj"],
            lora_dropout=0.05,
            bias="none",
            task_type="CAUSAL_LM"
        )
        
        # Create PEFT model
        self.model = get_peft_model(base_model, lora_config)
        
        # Move to GPU if available
        if torch.cuda.is_available():
            self.model = self.model.to("cuda")
            torch.backends.cuda.enable_flash_sdp(True)
            torch.backends.cuda.enable_mem_efficient_sdp(True)
            
    def save_pretrained(self, output_dir):
        """Save LoRA weights and tokenizer."""
        self.model.save_pretrained(output_dir)
        if hasattr(self, 'processing_class'):
            self.processing_class.save_pretrained(output_dir)
        elif hasattr(self, 'tokenizer'):
            self.tokenizer.save_pretrained(output_dir)
