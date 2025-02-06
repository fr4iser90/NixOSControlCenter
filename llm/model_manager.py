#!/usr/bin/env python3
import os
import sys
import json
import warnings
import inquirer
from pathlib import Path
import argparse
from typing import Optional

# Set up project root before importing path_config
os.environ['PROJECT_ROOT'] = str(Path.cwd())

from scripts.training.train_nixos_model import NixOSModelTrainer
from scripts.utils.path_config import ProjectPaths

# Filter out FutureWarning from transformers
warnings.filterwarnings('ignore', category=FutureWarning)

class ModelManager:
    """Manages model operations and training."""
    
    def __init__(self, test_mode: bool = False):
        """Initialize with optional test mode."""
        # Use centralized paths
        ProjectPaths.ensure_directories()
        self.base_dir = ProjectPaths.LLM_DIR
        self.models_dir = ProjectPaths.MODELS_DIR
        self.dataset_dir = ProjectPaths.DATASET_DIR
        self.current_model_dir = ProjectPaths.CURRENT_MODEL_DIR
        self.quantized_model_dir = ProjectPaths.QUANTIZED_MODEL_DIR
        self.test_mode = test_mode
        
        if test_mode:
            # Override dataset directory to only use core concepts for testing
            self.dataset_dir = ProjectPaths.DATASET_DIR / "concepts/00_fundamentals"
        
    def list_checkpoints(self) -> list[Path]:
        """List all available checkpoints in models directory"""
        if not self.models_dir.exists():
            return []
        return sorted([d for d in self.models_dir.glob('checkpoint-*') if d.is_dir()])
    
    def get_model_info(self) -> dict:
        """Get information about the model and available checkpoints"""
        available_models = {}
        
        # Scan for all model directories (excluding metrics and special dirs)
        for model_dir in self.models_dir.iterdir():
            if model_dir.is_dir() and model_dir.name not in ['metrics', 'quantized_model']:
                # Check for model files
                has_model = (
                    ((model_dir / 'adapter_config.json').exists() and
                     (model_dir / 'adapter_model.safetensors').exists()) or
                    ((model_dir / 'config.json').exists() and
                     any(model_dir.glob('pytorch_model*.bin')))
                )
                if has_model:
                    available_models[model_dir.name] = model_dir
        
        has_quantized = self.quantized_model_dir.exists()
        checkpoints = self.list_checkpoints()
        
        info = {
            'available_models': available_models,
            'has_quantized': has_quantized,
            'checkpoints': checkpoints,
        }
        return info

    def get_model_name(self) -> str:
        """Ask user for model name and version"""
        questions = [
            inquirer.Text('name',
                         message="Enter model name (default: NixOS)",
                         default="NixOS"),
            inquirer.Text('version',
                         message="Enter version (e.g. v1, v2.1)",
                         default="v1")
        ]
        
        answers = inquirer.prompt(questions)
        if not answers:
            return "NixOS_v1"
            
        name = answers['name'].replace(" ", "_")
        version = answers['version'].replace(" ", "")
        return f"{name}_{version}"
    
    def select_training_option(self) -> tuple[str, Optional[Path], Optional[str]]:
        """Let user select how to proceed with training"""
        model_info = self.get_model_info()
        choices = []
        
        # Add continue options for each available model
        for model_name, model_dir in model_info['available_models'].items():
            choices.append((f'Continue training {model_name}', ('continue', model_name)))
            
        if model_info['has_quantized']:
            choices.append(('Continue training with quantized model', ('quantized', None)))
        
        if model_info['checkpoints']:
            choices.append(('Load from specific checkpoint', ('checkpoint', None)))
            
        choices.append(('Start fresh training', ('fresh', None)))
        choices.append(('Exit', ('exit', None)))
        
        questions = [
            inquirer.List('action',
                         message="How would you like to proceed with training?",
                         choices=choices)
        ]
        
        answers = inquirer.prompt(questions)
        if not answers or answers['action'][0] == 'exit':
            sys.exit(0)
            
        action, selected_model = answers['action']
        checkpoint_path = None
        model_name = None
        
        if action == 'checkpoint':
            checkpoints = model_info['checkpoints']
            checkpoint_q = [
                inquirer.List('checkpoint',
                             message="Select checkpoint to load:",
                             choices=[(f"Checkpoint {cp.name.split('-')[1]}", cp) for cp in checkpoints])
            ]
            checkpoint_answer = inquirer.prompt(checkpoint_q)
            if checkpoint_answer:
                checkpoint_path = checkpoint_answer['checkpoint']
        
        if action == 'fresh':
            model_name = self.get_model_name()
        elif action == 'continue':
            model_name = selected_model
                
        return action, checkpoint_path, model_name
    
    def start_training(self, mode: str, checkpoint_path: Optional[Path] = None, model_name: Optional[str] = None):
        """Start model training with specified mode and checkpoint"""
        if mode == "continue":
            model_path = self.models_dir / model_name
            if not model_path.exists():
                print(f"Error: Model directory {model_path} does not exist")
                return
            print(f"Continuing training from model: {model_name}")
            trainer = NixOSModelTrainer(
                model_name_or_path=model_path,
                start_visualizer=True,
                visualizer_network_access=False,
                test_mode=self.test_mode
            )
        elif mode == "checkpoint":
            if not checkpoint_path:
                print("Error: No checkpoint specified for checkpoint training")
                return
            print(f"Continuing training from checkpoint: {checkpoint_path}")
            trainer = NixOSModelTrainer(
                model_name_or_path=checkpoint_path,
                start_visualizer=True,
                visualizer_network_access=False,
                test_mode=self.test_mode
            )
        else:
            if not model_name:
                questions = [
                    inquirer.Text('model_name',
                                message="Enter model name",
                                default="NixOS"),
                    inquirer.Text('version',
                                message="Enter version (e.g. v1, v2.1)",
                                default="v1")
                ]
                answers = inquirer.prompt(questions)
                if not answers:
                    return
                model_name = f"{answers['model_name']}-{answers['version']}"
                
            # Ask about visualization server
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
                    
                network_access = network_answers['network_access'].startswith('Yes')
            else:
                network_access = False
                
            trainer = NixOSModelTrainer(
                model_name_or_path=model_name,
                start_visualizer=start_visualizer,
                visualizer_network_access=network_access,
                test_mode=self.test_mode
            )
            
        try:
            trainer.setup()  # Initialize all components
            trainer.train()  # Start training
        finally:
            trainer.cleanup()  # Ensure cleanup happens

def main():
    """Main entry point with argument parsing."""
    parser = argparse.ArgumentParser(description='NixOS Model Manager')
    parser.add_argument('--test', action='store_true', 
                       help='Run in test mode using only core concepts dataset')
    args = parser.parse_args()
    
    manager = ModelManager(test_mode=args.test)
    if args.test:
        print("Running in test mode with core concepts dataset only")
    mode, checkpoint, model_name = manager.select_training_option()
    manager.start_training(mode, checkpoint, model_name)

if __name__ == "__main__":
    main()
