#!/usr/bin/env python3
"""Test script for NixOS model."""
import torch
from pathlib import Path
import logging
from typing import List, Optional, Dict, Any
import json
import time

from scripts.utils.path_config import ProjectPaths
from scripts.training.modules.model_management import ModelInitializer
from scripts.monitoring.resource_monitor import ResourceMonitor
from scripts.training.modules.visualization import VisualizationManager

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class NixOSModelTester:
    """Test harness for NixOS model."""
    
    def __init__(self, model_path: Optional[str] = None, enable_viz: bool = True):
        """Initialize model tester with optional visualization."""
        # Initialize paths
        ProjectPaths.ensure_directories()
        self.model_path = Path(model_path) if model_path else ProjectPaths.CURRENT_MODEL_DIR
        
        # Initialize components
        self.model_init = ModelInitializer(paths_config=ProjectPaths)
        self.resource_monitor = ResourceMonitor(ProjectPaths.MODELS_DIR)
        if enable_viz:
            self.viz_manager = VisualizationManager(ProjectPaths, network_access=False)
            self.viz_manager.start_server()
        
        # Load model and tokenizer
        logger.info(f"Loading model from {self.model_path}...")
        self.model, self.tokenizer = self.model_init.load_model_and_tokenizer(
            model_path=str(self.model_path),
            load_in_8bit=False,
            device_map="auto"
        )
        
        # Move to GPU if available
        if torch.cuda.is_available():
            self.model = self.model.to("cuda")
        
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
    
    def cleanup(self):
        """Cleanup resources."""
        if hasattr(self, 'viz_manager'):
            self.viz_manager.cleanup_server()
        self.resource_monitor.stop_monitoring()

def main():
    """Main entry point."""
    # Example test prompts
    test_prompts = [
        "What is NixOS and how does it differ from other Linux distributions?",
        "How do I install a package in NixOS?",
        "Explain the NixOS configuration system.",
        "What are flakes in NixOS and how do they work?",
        "How do I set up a development environment in NixOS?"
    ]
    
    try:
        # Initialize tester
        tester = NixOSModelTester()
        
        # Run tests
        results = tester.test_model(test_prompts)
        
        # Cleanup
        tester.cleanup()
        
    except Exception as e:
        logger.error(f"Error during testing: {e}")
        raise

if __name__ == "__main__":
    main()