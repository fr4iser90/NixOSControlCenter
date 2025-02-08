#!/usr/bin/env python3
"""Test script for NixOS model."""
import torch
from pathlib import Path
import logging
from typing import List, Optional, Dict, Any
import json
import time
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel, PeftConfig
import argparse

from scripts.utils.path_config import ProjectPaths
from scripts.training.modules.model_management import ModelInitializer
from scripts.monitoring.resource_monitor import ResourceMonitor
from scripts.training.modules.visualization import VisualizationManager

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ModelTester:
    """Test harness for NixOS model."""
    
    def __init__(self, model_path: Optional[str] = None, enable_viz: bool = True):
        """Initialize model tester with optional visualization."""
        # Initialize paths
        ProjectPaths.ensure_directories()
        self.model_path = Path(model_path) if model_path else ProjectPaths.CURRENT_MODEL_DIR
        
        # Check CUDA availability
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        logger.info(f"Using device: {self.device}")
        if self.device == "cuda":
            logger.info(f"GPU: {torch.cuda.get_device_name()}")
            logger.info(f"Memory allocated: {torch.cuda.memory_allocated(0) / 1024**2:.2f}MB")
            logger.info(f"Memory cached: {torch.cuda.memory_reserved(0) / 1024**2:.2f}MB")
        
        # Initialize components
        self.model_init = ModelInitializer(paths_config=ProjectPaths)
        self.resource_monitor = ResourceMonitor(ProjectPaths.MODELS_DIR)
        if enable_viz:
            self.viz_manager = VisualizationManager(ProjectPaths, network_access=False)
            self.viz_manager.start_server()
        
        # Load model and tokenizer directly
        logger.info(f"Loading model from {self.model_path}...")
        
        try:
            # First check if we have a LoRA model
            adapter_config_path = self.model_path / "adapter_config.json"
            if adapter_config_path.exists():
                logger.info("Found LoRA adapter configuration")
                config = PeftConfig.from_pretrained(self.model_path)
                
                # Load base model
                logger.info(f"Loading base model from {config.base_model_name_or_path}")
                base_model = AutoModelForCausalLM.from_pretrained(
                    config.base_model_name_or_path,
                    torch_dtype=torch.float16 if self.device == "cuda" else torch.float32,
                    low_cpu_mem_usage=True,
                    device_map=None  # Disable device map to avoid distributed features
                )
                
                # Load LoRA adapter
                logger.info("Applying LoRA adapter")
                self.model = PeftModel.from_pretrained(
                    base_model,
                    self.model_path,
                    torch_dtype=torch.float16 if self.device == "cuda" else torch.float32,
                    device_map=None  # Disable device map to avoid distributed features
                )
                
                # Move model to device manually
                self.model = self.model.to(self.device)
                
                # Merge LoRA weights for better inference
                logger.info("Merging LoRA weights for inference")
                self.model = self.model.merge_and_unload()
                
            else:
                # Load as regular model
                logger.info("Loading as regular model")
                self.model = AutoModelForCausalLM.from_pretrained(
                    self.model_path,
                    torch_dtype=torch.float16 if self.device == "cuda" else torch.float32,
                    low_cpu_mem_usage=True,
                    device_map=None  # Disable device map to avoid distributed features
                ).to(self.device)
            
            # Load tokenizer
            self.tokenizer = AutoTokenizer.from_pretrained(
                config.base_model_name_or_path if adapter_config_path.exists() else self.model_path,
                padding_side="left",
                trust_remote_code=True
            )
            self.tokenizer.pad_token = self.tokenizer.eos_token
            logger.info("Tokenizer loaded successfully")
            
            # Log model size
            total_params = sum(p.numel() for p in self.model.parameters())
            logger.info(f"Model size: {total_params / 1e6:.2f}M parameters")
            
            if self.device == "cuda":
                logger.info(f"GPU memory after loading: {torch.cuda.memory_allocated(0) / 1024**2:.2f}MB")
        
        except Exception as e:
            logger.error(f"Error loading model: {e}")
            raise
        
        logger.info("Model loaded successfully")
    
    def test_model(self, test_prompts: List[str], save_results: bool = True) -> List[Dict[str, Any]]:
        """Test model with a list of prompts and optionally save results."""
        self.model.eval()
        device = next(self.model.parameters()).device
        results = []
        
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
        
        logger.info("\nTesting model with NixOS prompts:")
        with torch.no_grad():
            for i, prompt in enumerate(test_prompts, 1):
                logger.info(f"\nGenerating response {i}/{len(test_prompts)}...")
                formatted_prompt = f"### Question: {prompt}\n\n### Answer:"
                
                try:
                    # Start resource monitoring
                    start_time = time.time()
                    self.resource_monitor.start_monitoring()
                    
                    # Generate response
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
                    
                    # Stop monitoring and get metrics
                    elapsed_time = time.time() - start_time
                    resource_metrics = self.resource_monitor.get_metrics()
                    
                    # Store result
                    result = {
                        "prompt": prompt,
                        "response": response,
                        "metrics": {
                            "generation_time": elapsed_time,
                            "resources": resource_metrics
                        }
                    }
                    results.append(result)
                    
                    # Update visualization
                    if hasattr(self, 'viz_manager'):
                        self.viz_manager.update_metrics({
                            'test_metrics': {
                                'generation_time': elapsed_time,
                                'resources': resource_metrics
                            }
                        })
                    
                    # Print results
                    logger.info(f"\nPrompt: {prompt}")
                    logger.info(f"Response: {response}")
                    logger.info(f"Generation Time: {elapsed_time:.2f}s")
                    logger.info("="*80)
                    
                except Exception as e:
                    logger.error(f"Error generating response: {e}")
                    continue
        
        if save_results:
            self._save_results(results)
        
        return results
    
    def _save_results(self, results: List[Dict[str, Any]]):
        """Save test results to file."""
        results_file = self.model_path / "test_results.json"
        try:
            with open(results_file, 'w') as f:
                json.dump(results, f, indent=2)
            logger.info(f"Test results saved to {results_file}")
        except Exception as e:
            logger.error(f"Error saving results: {e}")
    
    def chat(self):
        """Start an interactive chat session with the model."""
        logger.info("Starting interactive chat session. Type 'exit' to end.")
        logger.info("You can ask questions about NixOS, package management, system configuration, etc.")
        
        # Clear GPU memory at start
        if self.device == "cuda":
            torch.cuda.empty_cache()
            logger.info(f"Initial GPU memory: {torch.cuda.memory_allocated(0) / 1024**2:.2f}MB")
        
        # Set model to evaluation mode
        self.model.eval()
        
        # Debug: Print model and tokenizer info
        logger.info(f"Model type: {type(self.model)}")
        logger.info(f"Tokenizer type: {type(self.tokenizer)}")
        logger.info(f"Model device: {next(self.model.parameters()).device}")
        
        while True:
            try:
                # Get user input
                user_input = input("\nYou: ").strip()
                if user_input.lower() in ['exit', 'quit']:
                    break
                    
                # Generate response
                logger.info("Generating response...")
                start_time = time.time()
                
                try:
                    # Format input to match training data
                    prompt = (
                        "Below are questions and answers about NixOS concepts.\n\n"
                        "Question: What is NixOS?\n"
                        "Answer: [Basics] NixOS is a Linux distribution that uses the Nix package manager to configure systems declaratively and ensure reproducibility.\n\n"
                        "Question: What is the Nix Package Manager?\n"
                        "Answer: [Package Management] The Nix Package Manager is a powerful package manager for Linux and other Unix systems that enables reliable and reproducible package management.\n\n"
                        "Question: How does Nix handle dependencies?\n"
                        "Answer: [Package Management] Nix handles dependencies by storing them in isolated paths in /nix/store, ensuring no conflicts between versions or packages.\n\n"
                        f"Question: {user_input}\n"
                        "Answer: ["
                    )
                    
                    # Debug: Print prompt
                    logger.debug(f"Prompt: {prompt}")
                    
                    input_ids = self.tokenizer.encode(prompt, return_tensors='pt').to(self.device)
                    attention_mask = torch.ones_like(input_ids).to(self.device)
                    
                    # Debug: Print token info
                    logger.info(f"Input tokens: {input_ids.shape[1]}")
                    
                    # Generate with manual token generation to avoid distributed features
                    with torch.no_grad():
                        max_new_tokens = 150  # Shorter max length since answers are concise
                        output_ids = input_ids
                        current_length = input_ids.shape[1]
                        generated_tokens = []
                        
                        for i in range(max_new_tokens):
                            # Forward pass with limited context
                            context_size = 512
                            start_idx = max(0, output_ids.shape[1] - context_size)
                            
                            outputs = self.model(
                                input_ids=output_ids[:, start_idx:],
                                attention_mask=attention_mask[:, start_idx:]
                            )
                            logits = outputs.logits[:, -1, :]
                            
                            # Temperature sampling
                            logits = logits / 0.8  # Slightly higher temperature for more focused responses
                            
                            # Apply top-k
                            top_k = 40  # Reduced from 50 for more focused sampling
                            top_k_logits, top_k_indices = torch.topk(logits, top_k)
                            
                            # Apply softmax only to top-k logits
                            probs = torch.nn.functional.softmax(top_k_logits, dim=-1)
                            
                            # Sample from top-k
                            idx_next = torch.multinomial(probs, num_samples=1)
                            next_token = top_k_indices.gather(-1, idx_next)
                            
                            # Debug: Print token info periodically
                            if i % 10 == 0:
                                logger.debug(f"Generated token {i}: {next_token.item()} -> {self.tokenizer.decode([next_token.item()])}")
                            
                            # Append to sequence
                            output_ids = torch.cat([output_ids, next_token], dim=-1)
                            attention_mask = torch.cat([attention_mask, torch.ones_like(next_token)], dim=-1)
                            generated_tokens.append(next_token.item())
                            
                            # Check if we should stop
                            if next_token.item() == self.tokenizer.eos_token_id:
                                logger.debug("Found EOS token, stopping generation")
                                break
                            
                            # Also stop if we see "Question:" or "]" in the last few tokens
                            if i > 0 and i % 5 == 0:  # Check every 5 tokens
                                last_output = self.tokenizer.decode(output_ids[0, -20:])
                                if "Question:" in last_output or "] " in last_output:
                                    logger.debug("Found end marker, stopping generation")
                                    break
                            
                            current_length += 1
                            
                            # Stop if we're not generating anything meaningful
                            if i >= 5 and len(set(generated_tokens[-5:])) == 1:
                                logger.debug("Detected repetitive generation, stopping")
                                break
                    
                    # Debug: Print generation stats
                    logger.info(f"Generated {len(generated_tokens)} new tokens")
                    
                    # Decode only the generated part (exclude input)
                    response = self.tokenizer.decode(output_ids[0][input_ids.shape[1]:], skip_special_tokens=True)
                    
                    # Debug: Print raw response
                    logger.debug(f"Raw response: {response}")
                    
                    # Clean up response
                    response = response.strip()
                    if "]" in response:
                        response = response.split("]")[1].strip()
                    if "Question:" in response:
                        response = response.split("Question:")[0].strip()
                    
                    # Print response with timing
                    elapsed = time.time() - start_time
                    if not response:
                        response = "(The model generated an empty response. This might indicate an issue with the model or the generation process.)"
                    print(f"\nNixOS Assistant ({elapsed:.2f}s):\n{response}\n")
                    
                    # Log GPU memory if available
                    if self.device == "cuda":
                        logger.debug(f"GPU memory after generation: {torch.cuda.memory_allocated(0) / 1024**2:.2f}MB")
                    
                except RuntimeError as e:
                    if "out of memory" in str(e):
                        logger.error("GPU out of memory. Try a shorter input or free up GPU memory.")
                        if hasattr(torch.cuda, 'empty_cache'):
                            torch.cuda.empty_cache()
                    else:
                        logger.error(f"Error during generation: {e}")
                        logger.exception("Full traceback:")
                        
            except KeyboardInterrupt:
                break
            except Exception as e:
                logger.error(f"Error during chat: {e}")
                logger.exception("Full traceback:")
                continue
                
        logger.info("Chat session ended")
    
    def cleanup(self):
        """Cleanup resources."""
        if hasattr(self, 'viz_manager'):
            self.viz_manager.cleanup_server()
        self.resource_monitor.stop_monitoring()

def main():
    """Main entry point."""
    import argparse
    parser = argparse.ArgumentParser(description="Test NixOS model")
    parser.add_argument("--model-path", type=str, help="Path to model directory")
    parser.add_argument("--mode", choices=['test', 'chat'], default='chat',
                      help="Test mode: 'test' for automated tests, 'chat' for interactive chat")
    parser.add_argument("--no-viz", action="store_true", help="Disable visualization")
    args = parser.parse_args()
    
    # Initialize tester
    tester = ModelTester(
        model_path=args.model_path,
        enable_viz=not args.no_viz
    )
    
    if args.mode == 'chat':
        tester.chat()
    else:
        # Run automated tests
        test_prompts = [
            "What is NixOS?",
            "How do I install a package in NixOS?",
            "Explain the NixOS module system."
        ]
        results = tester.test_model(test_prompts)
        
        # Print results
        for i, result in enumerate(results):
            print(f"\nTest {i+1}:")
            print(f"Prompt: {result['prompt']}")
            print(f"Response: {result['response']}")
            print(f"Time: {result['metrics']['generation_time']:.2f}s")
        
        # Cleanup
        tester.cleanup()

if __name__ == "__main__":
    main()