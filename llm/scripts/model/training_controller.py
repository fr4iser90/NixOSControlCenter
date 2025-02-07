#!/usr/bin/env python3
"""Module for controlling model training operations."""
import logging
import inquirer
from pathlib import Path
from typing import Dict, Optional, Any

from ..utils.path_config import ProjectPaths
from ..training.train_nixos_model import NixOSModelTrainer
from ..training.modules.trainer_factory import TrainerFactory
from .model_info import ModelInfo

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class TrainingController:
    """Controls model training operations and user interactions."""
    
    def __init__(self, models_dir: Path, test_mode: bool = False):
        """Initialize training controller."""
        self.models_dir = models_dir
        self.test_mode = test_mode
        self.model_info = ModelInfo(models_dir)
        self.trainer_type = 'lora'  # Default trainer type
        self.start_visualizer = True  # Default visualization setting
        self.visualizer_network_access = False  # Default network access setting
        
    def start_training(self):
        """Start or continue model training."""
        available_models = self.model_info.get_available_models()
        
        if not available_models:
            logger.info("No existing models found. Starting fresh training with default model...")
            self.start_fresh_training()
            return

        questions = [
            inquirer.List('action',
                         message="How would you like to proceed with training?",
                         choices=['Continue training', 'Start fresh training', 'Test model', 'Exit'])
        ]
        answers = inquirer.prompt(questions)
        if not answers or answers['action'] == 'Exit':
            return
            
        if answers['action'] == 'Start fresh training':
            self.start_fresh_training()
        elif answers['action'] == 'Continue training':
            self._continue_training()
        elif answers['action'] == 'Test model':
            self._test_model()
            
    def start_fresh_training(self):
        """Start fresh training with default model."""
        # Get visualization preferences
        vis_questions = [
            inquirer.List('visualizer',
                message="Would you like to start the visualization server?",
                choices=['Yes', 'No'],
                default='Yes')
        ]
        vis_answers = inquirer.prompt(vis_questions)
        if not vis_answers:
            return
        self.start_visualizer = vis_answers['visualizer'] == 'Yes'
        
        if self.start_visualizer:
            net_questions = [
                inquirer.List('network_access',
                    message="Allow network access to visualization server?",
                    choices=['Yes (accessible from other devices)', 'No (localhost only)'],
                    default='No (localhost only)')
            ]
            net_answers = inquirer.prompt(net_questions)
            if not net_answers:
                return
            self.visualizer_network_access = net_answers['network_access'].startswith('Yes')
        
        # Start training with default model
        try:
            self.start_training_with_options(
                "facebook/opt-125m",
                mode='fresh',
                start_visualizer=self.start_visualizer,
                visualizer_network_access=self.visualizer_network_access
            )
        except Exception as e:
            logger.error(f"Error during fresh training: {e}")
        
    def start_training_with_options(
        self,
        model_name: str,
        mode: str = 'fresh',
        checkpoint_path: Optional[Path] = None,
        dataset_name: Optional[str] = None,
        hyperparameters: Optional[Dict] = None,
        resource_limits: Optional[Dict] = None,
        start_visualizer: bool = True,
        visualizer_network_access: bool = False
    ):
        """Start or resume model training with advanced options."""
        try:
            # Create trainer using factory
            trainer = TrainerFactory.create_trainer(
                trainer_type=self.trainer_type,
                model_path=model_name if mode == 'fresh' else checkpoint_path,
                config={
                    'hyperparameters': hyperparameters or {},
                    'resource_limits': resource_limits or {}
                },
                start_visualizer=start_visualizer,
                visualizer_network_access=visualizer_network_access,
                test_mode=self.test_mode
            )
            
            # Setup and start training
            trainer.setup()
            trainer.train()
            
        except Exception as e:
            logger.error(f"Error during training: {e}")
            raise
            
    def _continue_training(self):
        """Continue training an existing model."""
        model_name = self._select_model()
        if not model_name:
            return
            
        checkpoints = self.model_info.list_checkpoints(model_name)
        if checkpoints:
            checkpoint_questions = [
                inquirer.List('checkpoint',
                    message="Select checkpoint to continue from:",
                    choices=['Latest'] + [str(c) for c in checkpoints])
            ]
            checkpoint_answers = inquirer.prompt(checkpoint_questions)
            if not checkpoint_answers:
                return
                
            checkpoint = checkpoints[-1] if checkpoint_answers['checkpoint'] == 'Latest' else Path(checkpoint_answers['checkpoint'])
        else:
            checkpoint = None
            
        self.start_training_with_options(
            model_name,
            mode='continue',
            checkpoint_path=checkpoint,
            start_visualizer=self.start_visualizer,
            visualizer_network_access=self.visualizer_network_access
        )
        
    def _test_model(self):
        """Test a trained model."""
        model_name = self._select_model()
        if not model_name:
            return
            
        # Initialize trainer for testing
        try:
            trainer = TrainerFactory.create_trainer(
                trainer_type=self.trainer_type,
                model_path=str(self.models_dir / model_name),
                test_mode=True
            )
            trainer.setup()
            trainer.test()
        except Exception as e:
            logger.error(f"Error during model testing: {e}")
            
    def _select_model(self) -> Optional[str]:
        """Select a model from available models."""
        available_models = self.model_info.get_available_models()
        if not available_models:
            logger.warning("No trained models available")
            return None
            
        model_questions = [
            inquirer.List('model_name',
                message="Select model:",
                choices=available_models)
        ]
        model_answers = inquirer.prompt(model_questions)
        return model_answers['model_name'] if model_answers else None
