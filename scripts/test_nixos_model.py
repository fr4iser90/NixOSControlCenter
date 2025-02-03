#!/usr/bin/env python3
import torch
from pathlib import Path
from transformers import AutoTokenizer, AutoModelForCausalLM
from peft import LoraConfig, get_peft_model
from typing import List

class NixOSModelTester:
    def __init__(self, model_dir: str, model_name: str = "facebook/opt-125m"):
        self.model_dir = Path(model_dir)
        self.model_name = model_name
        
        print(f"Loading tokenizer and model from {model_name}...")
        self.tokenizer = AutoTokenizer.from_pretrained(
            model_name,
            padding_side="left",
            trust_remote_code=True
        )
        self.tokenizer.pad_token = self.tokenizer.eos_token
        
        # Load base model first
        print(f"Loading base model from {model_name}...")
        self.model = AutoModelForCausalLM.from_pretrained(
            model_name,
            torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
            device_map="auto",
            low_cpu_mem_usage=True
        )
        self.model.config.pad_token_id = self.tokenizer.eos_token_id
        
        # Apply LoRA config
        lora_config = LoraConfig(
            r=8,
            lora_alpha=32,
            target_modules=["q_proj", "v_proj"],
            lora_dropout=0.05,
            bias="none",
            task_type="CAUSAL_LM"
        )
        
        # Try to load from checkpoints
        checkpoint_dir = self.model_dir / "checkpoint-2000"
        if checkpoint_dir.exists():
            print(f"Loading from checkpoint: {checkpoint_dir}")
            self.model = get_peft_model(self.model, lora_config)
            self.model.load_adapter(checkpoint_dir, "default")
        else:
            print("No checkpoint found. Model responses will be random.")
            self.model = get_peft_model(self.model, lora_config)
        
        if torch.cuda.is_available():
            self.model = self.model.to("cuda")
        
    def test_model(self, test_prompts: List[str]):
        self.model.eval()
        device = next(self.model.parameters()).device
        
        generation_config = {
            "max_new_tokens": 256,
            "temperature": 0.7,
            "top_p": 0.9,
            "do_sample": True,
            "pad_token_id": self.tokenizer.eos_token_id,
            "eos_token_id": self.tokenizer.eos_token_id,
            "num_return_sequences": 1,
            "max_time": 30.0
        }
        
        print("\nTesting model with NixOS prompts:")
        with torch.no_grad():
            for i, prompt in enumerate(test_prompts, 1):
                print(f"\nGenerating response {i}/{len(test_prompts)}...")
                formatted_prompt = f"### Question: {prompt}\n\n### Answer:"
                
                try:
                    inputs = self.tokenizer(
                        formatted_prompt,
                        return_tensors="pt",
                        padding=True,
                        truncation=True,
                        max_length=512
                    ).to(device)
                    
                    outputs = self.model.generate(
                        input_ids=inputs.input_ids,
                        attention_mask=inputs.attention_mask,
                        **generation_config
                    )
                    
                    response = self.tokenizer.decode(
                        outputs[0][inputs.input_ids.shape[1]:],
                        skip_special_tokens=True
                    )
                    
                    print(f"\nPrompt: {prompt}")
                    print(f"Response: {response}")
                    print("="*80)
                except Exception as e:
                    print(f"Error generating response: {str(e)}")
                    continue

def main():
    test_prompts = [
        "What is NixOS and how is it different from other Linux distributions?",
        "How do I create a Python development environment with Poetry in NixOS?",
        "Explain how to update a NixOS system using flakes.",
        "How do I debug a broken NixOS configuration?",
        "Create a basic flake.nix for a Python web server with FastAPI"
    ]
    
    tester = NixOSModelTester(
        model_dir="/home/fr4iser/Documents/Git/NixOsControlCenter/models"
    )
    tester.test_model(test_prompts)

if __name__ == "__main__":
    main()