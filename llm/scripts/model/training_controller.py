#!/usr/bin/env python3
"""Module for controlling model training operations."""
import logging
import inquirer
from pathlib import Path
from typing import Dict, Optional, Any

from ..utils.path_config import ProjectPaths
from ..training.train_nixos_model import NixOSModelTrainer
from ..training.modules.trainer_factory import TrainerFactory
from ..training.modules.visualization import VisualizationManager
from ..training.modules.dataset_management import DatasetLoader
from ..data.dataset_manager import DatasetManager
from .model_info import ModelInfo

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
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
            model_dir = self.models_dir / model_name
            
            if model_dir.exists():
                logger.error(f"Model '{model_name}' already exists")
                return
                
            # Create model directory
            model_dir.mkdir(parents=True, exist_ok=True)
            
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
            
            # Start training with options
            self.start_training_with_options(
                model_name='facebook/opt-125m',  # Base model
                mode='fresh',
                checkpoint_path=model_dir,
                start_visualizer=self.start_visualizer,
                visualizer_network_access=self.visualizer_network_access
            )
            
        except Exception as e:
            logger.error(f"Error during fresh training: {e}")
            raise
            
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
            # Initialize visualization if requested
            visualizer = None
            if start_visualizer:
                visualizer = VisualizationManager(
                    ProjectPaths(),
                    network_access=visualizer_network_access
                )
            
            # Load datasets
            logger.info("Loading training datasets...")
            if self.test_mode:
                train_dataset, eval_dataset = self.dataset_loader.load_test_dataset()
            else:
                train_dataset, eval_dataset = self.dataset_loader.load_and_validate_processed_datasets()
            
            # Create trainer using factory
            trainer = TrainerFactory.create_trainer(
                trainer_type=self.trainer_type,
                model_path=model_name if mode == 'fresh' else checkpoint_path,
                config={
                    'hyperparameters': hyperparameters or {},
                    'resource_limits': resource_limits or {},
                    'output_dir': str(checkpoint_path) if checkpoint_path else None
                },
                dataset_manager=self.dataset_manager,
                visualizer=visualizer,
                train_dataset=train_dataset,
                eval_dataset=eval_dataset
            )
            
            # Start training
            trainer.train()
            
            # Save model after training
            if checkpoint_path:
                logger.info(f"Saving model to {checkpoint_path}")
                trainer.save_model(str(checkpoint_path))
                logger.info("Model saved successfully")
            
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
            
            # Start training with options
            self.start_training_with_options(
                model_name='facebook/opt-125m',  # Base model
                mode='continue',
                checkpoint_path=model_dir,
                start_visualizer=self.start_visualizer,
                visualizer_network_access=self.visualizer_network_access
            )
            
        except Exception as e:
            logger.error(f"Error during continued training: {e}")
            raise
            
    def _test_model(self):
        """Test a trained model."""
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
                
            # Load test dataset
            logger.info("Loading test dataset...")
            test_dataset = self.dataset_loader.load_test_data()
            
            # Create trainer for testing
            trainer = TrainerFactory.create_trainer(
                trainer_type=self.trainer_type,
                model_path=str(model_dir),  # Use the trained model path
                config={
                    'hyperparameters': {},
                    'resource_limits': {},
                    'output_dir': str(model_dir / 'test_results'),
                    'evaluation_strategy': 'epoch',
                    'do_train': False,
                    'do_eval': True
                },
                dataset_manager=self.dataset_manager,
                eval_dataset=test_dataset
            )
            
            # Run evaluation
            logger.info("Starting model evaluation...")
            eval_results = trainer.evaluate()
            
            # Log results
            logger.info("Evaluation Results:")
            for metric, value in eval_results.items():
                logger.info(f"{metric}: {value}")
                
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
