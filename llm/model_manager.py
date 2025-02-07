#!/usr/bin/env python3
"""Model Manager for LLM Training Center."""
import os
import sys
import json
import warnings
import inquirer
from pathlib import Path
import argparse
from typing import Optional, Dict, List, Union, Any
import logging
from datetime import datetime

# Import and setup paths first
from scripts.utils.path_config import ProjectPaths
ProjectPaths.setup_python_path()

from scripts.training.train_nixos_model import NixOSModelTrainer
from scripts.training.modules.model_interpretation import ModelInterpreter
from scripts.monitoring.resource_monitor import ResourceMonitor
from scripts.training.modules.training import TrainingManager

# Filter warnings
warnings.filterwarnings('ignore', category=FutureWarning)

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ModelManager:
    """Manages model operations, training, and evaluation."""
    
    def __init__(
        self,
        test_mode: bool = False
    ):
        """Initialize with optional test mode."""
        # Use centralized paths
        self.base_dir = ProjectPaths.LLM_DIR
        self.models_dir = ProjectPaths.MODELS_DIR
        self.dataset_dir = ProjectPaths.DATASET_DIR
        self.current_model_dir = ProjectPaths.CURRENT_MODEL_DIR
        self.quantized_model_dir = ProjectPaths.QUANTIZED_MODEL_DIR
        self.test_mode = test_mode
        
        # Initialize components
        self.resource_monitor = ResourceMonitor(self.models_dir)
        self.training_manager = TrainingManager(
            "NixOS",
            self.models_dir,
            test_mode=test_mode
        )
        
        if test_mode:
            self.dataset_dir = ProjectPaths.DATASET_DIR / "concepts/00_fundamentals"
    
    def get_model_overview(self, model_name: str) -> Dict[str, Any]:
        """Get comprehensive model overview including history and metrics."""
        model_dir = self.models_dir / model_name
        overview = {
            'name': model_name,
            'history': self._load_training_history(model_name),
            'architecture': self._get_model_architecture(model_name),
            'performance': self._get_performance_metrics(model_name),
            'checkpoints': self.list_checkpoints(model_name),
            'datasets': self._get_datasets_used(model_name)
        }
        return overview
    
    def list_checkpoints(self, model_name: Optional[str] = None) -> List[Path]:
        """List all available checkpoints for a model."""
        if model_name:
            model_dir = self.models_dir / model_name
            if not model_dir.exists():
                return []
            return sorted([d for d in model_dir.glob('checkpoint-*') if d.is_dir()])
        else:
            if not self.models_dir.exists():
                return []
            return sorted([d for d in self.models_dir.glob('**/checkpoint-*') if d.is_dir()])
    
    def get_model_info(self) -> Dict[str, Any]:
        """Get detailed information about available models and checkpoints."""
        available_models = {}
        
        for model_dir in self.models_dir.iterdir():
            if model_dir.is_dir() and model_dir.name not in ['metrics', 'quantized_model']:
                has_model = (
                    ((model_dir / 'adapter_config.json').exists() and
                     (model_dir / 'adapter_model.safetensors').exists()) or
                    ((model_dir / 'config.json').exists() and
                     any(model_dir.glob('pytorch_model*.bin')))
                )
                if has_model:
                    available_models[model_dir.name] = {
                        'path': model_dir,
                        'overview': self.get_model_overview(model_dir.name),
                        'checkpoints': self.list_checkpoints(model_dir.name)
                    }
        
        return {
            'available_models': available_models,
            'has_quantized': self.quantized_model_dir.exists(),
            'total_checkpoints': len(self.list_checkpoints())
        }
    
    def start_training(
        self,
        model_name: str,
        mode: str = 'fresh',
        checkpoint_path: Optional[Path] = None,
        dataset_name: Optional[str] = None,
        hyperparameters: Optional[Dict] = None,
        resource_limits: Optional[Dict] = None,
        start_visualizer: bool = True,
        visualizer_network_access: bool = False
    ) -> Dict[str, Any]:
        """Start or resume model training with advanced options."""
        try:
            # Start resource monitoring
            self.resource_monitor.start_monitoring()
            
            # Initialize trainer with resource limits
            trainer = NixOSModelTrainer(
                model_name_or_path=checkpoint_path or model_name,
                start_visualizer=start_visualizer,
                visualizer_network_access=visualizer_network_access,
                test_mode=self.test_mode
            )
            
            if resource_limits:
                trainer.set_resource_limits(**resource_limits)
            
            # Set up training configuration
            training_config = {
                'model_name': model_name,
                'mode': mode,
                'checkpoint': str(checkpoint_path) if checkpoint_path else None,
                'dataset': dataset_name,
                'hyperparameters': hyperparameters or {},
                'resource_limits': resource_limits or {},
                'visualization': {
                    'enabled': start_visualizer,
                    'network_access': visualizer_network_access
                },
                'start_time': datetime.now().isoformat()
            }
            
            # Start training
            results = trainer.train()
            
            # Get resource usage report
            resource_report = self.resource_monitor.generate_report()
            
            # Save training history
            self._save_training_history(model_name, {
                'config': training_config,
                'results': results,
                'resource_usage': resource_report
            })
            
            return {
                'training_results': results,
                'resource_usage': resource_report,
                'model_path': str(trainer.output_dir)
            }
            
        except Exception as e:
            logger.error(f"Training error: {str(e)}")
            raise
        finally:
            self.resource_monitor.stop_monitoring()
    
    def evaluate_model(
        self,
        model_name: str,
        test_dataset: Optional[str] = None,
        checkpoint: Optional[Path] = None
    ) -> Dict[str, Any]:
        """Evaluate model performance with detailed metrics."""
        try:
            model_path = checkpoint or self.models_dir / model_name
            trainer = NixOSModelTrainer(
                model_name_or_path=model_path,
                test_mode=self.test_mode
            )
            
            # Run evaluation
            eval_results = trainer.evaluate(test_dataset)
            
            # Get model interpretations
            interpreter = ModelInterpreter(trainer.model, trainer.tokenizer)
            interpretation_results = interpreter.analyze_errors(
                trainer.dataset_loader.load_test_data(test_dataset)
            )
            
            # Combine results
            results = {
                'evaluation_metrics': eval_results,
                'interpretation': interpretation_results,
                'timestamp': datetime.now().isoformat()
            }
            
            # Save results
            self._save_evaluation_results(model_name, results)
            
            return results
            
        except Exception as e:
            logger.error(f"Evaluation error: {str(e)}")
            raise
    
    def explain_prediction(
        self,
        model_name: str,
        text: str,
        checkpoint: Optional[Path] = None
    ) -> Dict[str, Any]:
        """Generate model interpretation for a prediction."""
        try:
            model_path = checkpoint or self.models_dir / model_name
            trainer = NixOSModelTrainer(
                model_name_or_path=model_path,
                test_mode=self.test_mode
            )
            
            interpreter = ModelInterpreter(trainer.model, trainer.tokenizer)
            explanation = interpreter.explain_prediction(text)
            
            return explanation
            
        except Exception as e:
            logger.error(f"Explanation error: {str(e)}")
            raise
    
    def test_llm(self, model_path: str, mode: str = 'predefined'):
        """Test LLM with either predefined questions or interactive chat.
        
        Args:
            model_path: Path to the model to test
            mode: Either 'predefined' or 'chat'
        """
        from scripts.test.test_nixos_model import NixOSModelTester
        
        print("\nInitializing model tester...")
        tester = NixOSModelTester(model_path=model_path)
        
        if mode == 'predefined':
            # Comprehensive test questions about NixOS
            test_prompts = [
                # Basic NixOS Concepts
                "What is NixOS and how does it differ from other Linux distributions?",
                "Explain the Nix package manager and its key features.",
                "What is declarative configuration in NixOS?",
                
                # Package Management
                "How do I install a package in NixOS?",
                "Explain the difference between system-wide and user packages in NixOS.",
                "How do I update my system in NixOS?",
                
                # Configuration Management
                "How do I edit my NixOS configuration?",
                "Explain how to add a new service to NixOS.",
                "How do I switch between NixOS configurations?",
                
                # Advanced Topics
                "What are flakes in NixOS and how do they work?",
                "Explain NixOS modules and how to create them.",
                "How does NixOS handle system rollbacks?",
                
                # Development
                "How do I set up a development environment in NixOS?",
                "Explain how to use nix-shell for development.",
                "How do I package my own software for NixOS?"
            ]
            
            print("\nRunning predefined test questions...")
            results = tester.test_model(test_prompts)
            
            # Display results
            print("\nTest Results:")
            for i, (prompt, response) in enumerate(zip(test_prompts, results), 1):
                print(f"\nQ{i}: {prompt}")
                print(f"A: {response['generated_text']}")
                if 'metrics' in response:
                    print(f"Response time: {response['metrics']['response_time']:.2f}s")
                    print(f"Token count: {response['metrics']['token_count']}")
                print("-" * 80)
            
        else:  # chat mode
            print("\nEntering interactive chat mode. Type 'exit' to quit.")
            print("You can ask any questions about NixOS, package management, system configuration, etc.")
            
            while True:
                try:
                    user_input = input("\nYou: ").strip()
                    if user_input.lower() in ['exit', 'quit', 'q']:
                        break
                    
                    response = tester.test_model([user_input])[0]
                    print(f"\nNixOS AI: {response['generated_text']}")
                    
                    if 'metrics' in response:
                        print(f"\nResponse generated in {response['metrics']['response_time']:.2f}s")
                        
                except KeyboardInterrupt:
                    print("\nExiting chat mode...")
                    break
                except Exception as e:
                    print(f"\nError: {str(e)}")
                    print("Please try again or type 'exit' to quit.")
        
        print("\nTest session completed.")
    
    def _load_training_history(self, model_name: str) -> List[Dict]:
        """Load training history for a model."""
        history_file = self.models_dir / model_name / "training_history.json"
        if not history_file.exists():
            return []
        
        with open(history_file, 'r') as f:
            return json.load(f)
    
    def _save_training_history(self, model_name: str, history_entry: Dict):
        """Save training history entry."""
        history_file = self.models_dir / model_name / "training_history.json"
        history = self._load_training_history(model_name)
        history.append(history_entry)
        
        with open(history_file, 'w') as f:
            json.dump(history, f, indent=2)
    
    def _save_evaluation_results(self, model_name: str, results: Dict):
        """Save evaluation results."""
        eval_dir = self.models_dir / model_name / "evaluations"
        eval_dir.mkdir(exist_ok=True)
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        result_file = eval_dir / f"evaluation_{timestamp}.json"
        
        with open(result_file, 'w') as f:
            json.dump(results, f, indent=2)
    
    def _get_model_architecture(self, model_name: str) -> Dict[str, Any]:
        """Get model architecture information."""
        config_file = self.models_dir / model_name / "config.json"
        if not config_file.exists():
            return {}
        
        with open(config_file, 'r') as f:
            return json.load(f)
    
    def _get_performance_metrics(self, model_name: str) -> Dict[str, Any]:
        """Get model performance metrics."""
        metrics_file = self.models_dir / model_name / "metrics.json"
        if not metrics_file.exists():
            return {}
        
        with open(metrics_file, 'r') as f:
            return json.load(f)
    
    def _get_datasets_used(self, model_name: str) -> List[str]:
        """Get list of datasets used in training."""
        history = self._load_training_history(model_name)
        datasets = set()
        for entry in history:
            if 'config' in entry and 'dataset' in entry['config']:
                datasets.add(entry['config']['dataset'])
        return list(datasets)

def main():
    """Main entry point with argument parsing."""
    parser = argparse.ArgumentParser(description='LLM Training Manager')
    parser.add_argument('--test', action='store_true', help='Run in test mode with core concepts dataset only')
    parser.add_argument('--test-llm', action='store_true', help='Test trained LLM capabilities')
    parser.add_argument('--model-path', type=str, help='Path to model for testing')
    parser.add_argument('--mode', choices=['predefined', 'chat'], default='predefined',
                       help='Testing mode: predefined questions or interactive chat')
    args = parser.parse_args()
    
    # Initialize paths
    ProjectPaths.setup_python_path()
    
    manager = ModelManager(test_mode=args.test)
    
    if args.test_llm:
        if not args.model_path:
            print("Error: --model-path is required for --test-llm")
            return
        manager.test_llm(args.model_path, args.mode)
        return
    
    model_info = manager.get_model_info()
    print("\nScanning directory:", ProjectPaths.MODELS_DIR)
    for model_name, model_data in model_info['available_models'].items():
        print("Checking directory:", model_name)
        model_path = ProjectPaths.MODELS_DIR / model_name
        if (model_path / 'adapter_model.safetensors').exists():
            print("Found model files in {}: {}".format(model_name, ['adapter_model.safetensors']))
        config_files = [f.name for f in model_path.glob('*.json')]
        if config_files:
            print("Found config files in {}: {}".format(model_name, config_files))
        print(f"Adding model: {model_name}")
    
    print("\nAvailable models:", list(model_info['available_models'].keys()))
    
    # Model action selection
    questions = [
        inquirer.List('action',
                     message='How would you like to proceed with training?',
                     choices=['Continue training',
                             'Start fresh training',
                             'Test model',
                             'Exit'],
                     default='Continue training')
    ]
    answers = inquirer.prompt(questions)
    if not answers or answers['action'] == 'Exit':
        return
    
    # Model selection for all actions
    available_models = list(model_info['available_models'].keys())
    if not available_models:
        print("No models available.")
        return
        
    model_questions = [
        inquirer.List('model_name',
                     message='Select model:',
                     choices=available_models)
    ]
    model_answers = inquirer.prompt(model_questions)
    if not model_answers:
        return
    
    model_name = model_answers['model_name']
    
    if answers['action'] == 'Test model':
        # Test mode selection
        test_questions = [
            inquirer.List('test_mode',
                         message='Select test mode:',
                         choices=['Chat', 'Predefined questions'],
                         default='Chat')
        ]
        test_answers = inquirer.prompt(test_questions)
        if not test_answers:
            return
            
        mode = 'chat' if test_answers['test_mode'] == 'Chat' else 'predefined'
        model_path = str(ProjectPaths.MODELS_DIR / model_name)
        manager.test_llm(model_path, mode)
        return
    
    mode = 'fresh' if answers['action'] == 'Start fresh training' else 'continue'
    checkpoint_path = None
    
    # Visualization options
    vis_questions = [
        inquirer.List('visualizer',
                     message="Would you like to start the visualization server?",
                     choices=['Yes', 'No'],
                     default='Yes')
    ]
    vis_answers = inquirer.prompt(vis_questions)
    if not vis_answers:
        return
    
    start_visualizer = vis_answers['visualizer'] == 'Yes'
    visualizer_network_access = False
    
    if start_visualizer:
        vis_network_questions = [
            inquirer.List('network_access',
                         message="Allow network access to visualization server?",
                         choices=['Yes (accessible from other devices)', 'No (localhost only)'],
                         default='No (localhost only)')
        ]
        network_answers = inquirer.prompt(vis_network_questions)
        if not network_answers:
            return
        
        visualizer_network_access = network_answers['network_access'].startswith('Yes')
    
    # Training configuration
    hyperparameters = {}  # TODO: Add interactive hyperparameter configuration
    resource_limits = {}  # TODO: Add interactive resource limit configuration
    
    # Start training
    try:
        results = manager.start_training(
            model_name,
            mode,
            checkpoint_path,
            None,  # dataset_name is now handled internally
            hyperparameters,
            resource_limits,
            start_visualizer,
            visualizer_network_access
        )
        print("\nTraining started successfully!")
        print(f"Model path: {results['model_path']}")
        if start_visualizer:
            print("\nVisualization dashboard will be available at:")
            print("http://localhost:8501 (local)")
            if visualizer_network_access:
                print("http://<your-ip>:8501 (network)")
    except Exception as e:
        print(f"\nError starting training: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
