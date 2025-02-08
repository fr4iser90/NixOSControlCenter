#!/usr/bin/env python3
"""Module for controlling model training operations."""
import warnings
import logging
import inquirer
import subprocess
from pathlib import Path
from typing import Dict, Optional, Any

from scripts.utils.path_config import ProjectPaths
from scripts.training.train_model import LLMHub
from scripts.training.modules.trainer_factory import TrainerFactory
from scripts.training.modules.visualization import VisualizationManager
from scripts.training.modules.dataset_management import DatasetLoader
from scripts.data.dataset_manager import DatasetManager
from scripts.model.model_info import ModelInfo
from scripts.training.modules.training_config import ConfigManager

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

__all__ = ['TrainingController']

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
        self.visualizer = None  # Initialize as None
        
        # Initialize dataset components
        self.dataset_manager = DatasetManager()
        self.dataset_loader = DatasetLoader(
            self.dataset_manager,
            str(ProjectPaths.DATASET_DIR)
        )
        
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
        """Start fresh training with a new model."""
        try:
            # Get model name from user
            questions = [
                inquirer.Text(
                    'model_name',
                    message="Enter a name for the new model",
                    validate=lambda _, x: bool(x.strip())
                )
            ]
            answers = inquirer.prompt(questions)
            if not answers:
                logger.info("Training cancelled by user")
                return
                
            model_name = answers['model_name'].strip()
            
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
                
                # Initialize visualizer if requested
                self.visualizer = VisualizationManager(
                    ProjectPaths(),
                    network_access=self.visualizer_network_access
                )
                if self.start_visualizer:
                    self.visualizer.start_server()
            
            # Create model directory
            model_dir = self.models_dir / model_name
            model_dir.mkdir(parents=True, exist_ok=True)
            
            # Start training with options
            self.start_training_with_options(
                model_name=model_name,
                mode='fresh',
                start_visualizer=self.start_visualizer,
                visualizer_network_access=self.visualizer_network_access
            )
            
        except Exception as e:
            logger.error(f"Error during fresh training: {e}")
            raise
            
    def start_training_with_options(self, model_name: str, mode: str = 'fresh', **kwargs):
        """Start training with the given options.
        
        Args:
            model_name: Name of the model
            mode: Training mode ('fresh' or 'continue')
            **kwargs: Additional training options
        """
        try:
            # Load datasets
            logger.info("Loading training datasets...")
            train_dataset, eval_dataset = self.dataset_loader.load_and_validate_processed_datasets()
            
            # Get default config and merge with any overrides
            training_config = ConfigManager.get_default_config()
            if kwargs:
                training_config = ConfigManager.merge_config(training_config, kwargs)
            
            # Ensure output directory is set
            training_config['output_dir'] = str(self.models_dir / model_name)
            
            # Create trainer
            model_dir = self.models_dir / model_name
            trainer = TrainerFactory.create_trainer(
                trainer_type='lora',  # TODO: Make configurable
                model_path=str(model_dir) if mode == 'continue' else 'facebook/opt-125m',
                config=training_config,
                dataset_manager=self.dataset_manager,
                dataset_path=ProjectPaths.DATASET_DIR / "training_data.jsonl",
                visualizer=self.visualizer,
                train_dataset=train_dataset,
                eval_dataset=eval_dataset
            )
            
            # Start training
            if mode == 'continue':
                trainer.train(resume_from_checkpoint=True)
            else:
                trainer.train()
            
            # Save the model
            trainer.save_model(str(self.models_dir / model_name))
            
        except Exception as e:
            logger.error(f"Error during training: {e}")
            raise
            
    def _continue_training(self):
        """Continue training an existing model."""
        try:
            # Get available models
            available_models = self.model_info.get_available_models()
            if not available_models:
                logger.info("No existing models found")
                return
                
            # Let user select model
            questions = [
                inquirer.List('model',
                    message="Select model:",
                    choices=available_models)
            ]
            answers = inquirer.prompt(questions)
            if not answers:
                return
                
            selected_model = answers['model']
            model_dir = self.models_dir / selected_model
            
            if not model_dir.exists():
                logger.error(f"Model directory not found: {model_dir}")
                return
                
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
                
                # Initialize visualizer if requested
                self.visualizer = VisualizationManager(
                    ProjectPaths(),
                    network_access=self.visualizer_network_access
                )
                if self.start_visualizer:
                    self.visualizer.start_server()
            
            # Start training with options
            self.start_training_with_options(
                model_name=selected_model,
                mode='continue',
                start_visualizer=self.start_visualizer,
                visualizer_network_access=self.visualizer_network_access
            )
            
        except Exception as e:
            logger.error(f"Error during continued training: {e}")
            raise
            
    def _test_model(self):
        """Test the trained model."""
        try:
            # Get model selection
            available_models = self.model_info.get_available_models()
            if not available_models:
                logger.warning("No trained models found.")
                return
                
            questions = [
                inquirer.List('model',
                            message="Select model:",
                            choices=available_models),
                inquirer.List('mode',
                            message="Select test mode:",
                            choices=['Interactive Chat', 'Automated Tests'])
            ]
            answers = inquirer.prompt(questions)
            if not answers:
                return
                
            model_path = str(self.models_dir / answers['model'])
            
            # Import here to avoid circular imports
            from scripts.test.test_nixos_model import NixOSModelTester
            
            # Initialize tester
            tester = NixOSModelTester(
                model_path=model_path,
                enable_viz=self.start_visualizer
            )
            
            try:
                # Run tests based on mode
                if answers['mode'] == 'Interactive Chat':
                    tester.chat()
                else:
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
            finally:
                # Always cleanup
                tester.cleanup()
            
        except Exception as e:
            logger.error(f"Error during model testing: {e}")
            raise
            
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
