#!/usr/bin/env python3
import os
import sys
import json
import warnings
from pathlib import Path
from typing import Optional
import inquirer
from scripts.training.train_nixos_model import NixOSModelTrainer
from scripts.utils.path_config import ProjectPaths

# Filter out FutureWarning from transformers
warnings.filterwarnings('ignore', category=FutureWarning)

class ModelManager:
    def __init__(self):
        # Use centralized paths
        ProjectPaths.ensure_directories()
        self.base_dir = ProjectPaths.LLM_DIR
        self.models_dir = ProjectPaths.MODELS_DIR
        self.dataset_dir = ProjectPaths.DATASET_DIR
        self.current_model_dir = ProjectPaths.CURRENT_MODEL_DIR
        self.quantized_model_dir = ProjectPaths.QUANTIZED_MODEL_DIR
        
    def list_checkpoints(self) -> list[Path]:
        """List all available checkpoints in models directory"""
        if not self.models_dir.exists():
            return []
        return sorted([d for d in self.models_dir.glob('checkpoint-*') if d.is_dir()])
    
    def get_model_info(self) -> dict:
        """Get information about the model and available checkpoints"""
        has_model = False
        if self.current_model_dir.exists():
            # Check for either adapter files or full model files
            has_model = (
                ((self.current_model_dir / 'adapter_config.json').exists() and
                 (self.current_model_dir / 'adapter_model.safetensors').exists()) or
                ((self.current_model_dir / 'config.json').exists() and
                 any(self.current_model_dir.glob('pytorch_model*.bin')))
            )
        
        has_quantized = self.quantized_model_dir.exists()
        checkpoints = self.list_checkpoints()
        
        info = {
            'has_model': has_model,
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
        
        if model_info['has_model']:
            choices.append(('Continue training with existing model', 'continue'))
            
        if model_info['has_quantized']:
            choices.append(('Continue training with quantized model', 'quantized'))
        
        if model_info['checkpoints']:
            choices.append(('Load from specific checkpoint', 'checkpoint'))
            
        choices.append(('Start fresh training', 'fresh'))
        choices.append(('Exit', 'exit'))
        
        questions = [
            inquirer.List('action',
                         message="How would you like to proceed with training?",
                         choices=choices)
        ]
        
        answers = inquirer.prompt(questions)
        if not answers or answers['action'] == 'exit':
            sys.exit(0)
            
        checkpoint_path = None
        model_name = None
        
        if answers['action'] == 'checkpoint':
            checkpoints = model_info['checkpoints']
            checkpoint_q = [
                inquirer.List('checkpoint',
                             message="Select checkpoint to load:",
                             choices=[(f"Checkpoint {cp.name.split('-')[1]}", cp) for cp in checkpoints])
            ]
            checkpoint_answer = inquirer.prompt(checkpoint_q)
            if checkpoint_answer:
                checkpoint_path = checkpoint_answer['checkpoint']
        
        if answers['action'] == 'fresh':
            model_name = self.get_model_name()
                
        return answers['action'], checkpoint_path, model_name
    
    def start_training(self, mode: str, checkpoint_path: Optional[Path] = None, model_name: Optional[str] = None):
        """Initialize and start the training process"""
        if model_name:
            output_dir = self.models_dir / model_name
        else:
            output_dir = self.current_model_dir
        
        if mode == 'fresh':
            # Backup existing model if it exists
            if output_dir.exists():
                backup_dir = output_dir.parent / f"{output_dir.name}_backup"
                if backup_dir.exists():
                    import shutil
                    shutil.rmtree(backup_dir)
                output_dir.rename(backup_dir)
                print(f"Backed up existing model to {backup_dir}")
            model_path = 'facebook/opt-125m'
        else:
            # Use existing model or checkpoint
            if checkpoint_path:
                model_path = str(checkpoint_path)
            elif mode == 'quantized' and self.quantized_model_dir.exists():
                model_path = str(self.quantized_model_dir)
            else:
                model_path = str(self.current_model_dir)
            
        trainer = NixOSModelTrainer(
            model_name=model_path
        )
        
        if checkpoint_path:
            print(f"Loading from checkpoint: {checkpoint_path}")
            
        trainer.train()

def main():
    manager = ModelManager()
    mode, checkpoint, model_name = manager.select_training_option()
    manager.start_training(mode, checkpoint, model_name)

if __name__ == "__main__":
    main()
