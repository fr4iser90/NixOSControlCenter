#!/usr/bin/env python3
"""Main training script for NixOS model."""
import logging
from pathlib import Path
from typing import Optional

from ..utils.path_config import ProjectPaths
from ..data.dataset_manager import DatasetManager
from ..data.dataset_improver import DatasetImprover

from .modules.model_management import ModelInitializer
from .modules.dataset_management import DatasetLoader
from .modules.training import TrainingManager
from .modules.visualization import VisualizationManager
from .modules.feedback import FeedbackManager

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class NixOSModelTrainer:
    """Main trainer class orchestrating all components."""
    
    def __init__(
        self,
        model_name: str = "NixOS",
        start_visualizer: bool = False,
        visualizer_network_access: bool = False
    ):
        """Initialize trainer with all necessary components."""
        self.model_name = model_name
        
        # Initialize paths
        ProjectPaths.ensure_directories()
        self.output_dir = ProjectPaths.MODELS_DIR / model_name
        self.dataset_dir = str(ProjectPaths.DATASET_DIR)
        
        # Initialize components
        self.model_initializer = ModelInitializer(ProjectPaths)
        self.dataset_manager = DatasetManager()
        self.dataset_loader = DatasetLoader(self.dataset_manager, self.dataset_dir)
        self.training_manager = TrainingManager(model_name, self.output_dir)
        self.visualization_manager = VisualizationManager(
            ProjectPaths,
            visualizer_network_access
        ) if start_visualizer else None
        self.feedback_manager = FeedbackManager(DatasetImprover())
        
        # Initialize model components
        self.model = None
        self.tokenizer = None
        self.trainer = None
        
    def setup(self):
        """Set up all components for training."""
        # Start visualization if requested
        if self.visualization_manager:
            self.visualization_manager.start_server()
            
        # Initialize model and tokenizer
        logger.info("Initializing model and tokenizer...")
        self.model, self.tokenizer = self.model_initializer.initialize_model(
            self.model_name
        )
        
        # Load datasets
        logger.info("Loading and preparing datasets...")
        train_dataset, eval_dataset = self.dataset_loader.load_and_validate_datasets()
        
        # Initialize trainer
        logger.info("Setting up trainer...")
        self.trainer = self.training_manager.initialize_trainer(
            model=self.model,
            train_dataset=train_dataset,
            eval_dataset=eval_dataset,
            tokenizer=self.tokenizer
        )
        
    def train(self):
        """Run the training process."""
        if not self.trainer:
            logger.error("Trainer not initialized. Run setup() first.")
            return False
            
        try:
            # Start training
            logger.info("Starting training process...")
            success = self.training_manager.train_model(self.trainer)
            
            if success:
                # Save the model
                self.training_manager.save_checkpoints(self.trainer)
                
                # Analyze feedback and improve datasets
                analysis = self.feedback_manager.analyze_feedback()
                if analysis:
                    self.feedback_manager.improve_datasets(analysis)
                    
            return success
            
        except Exception as e:
            logger.error(f"Error during training: {e}")
            return False
            
    def cleanup(self):
        """Clean up resources."""
        if self.visualization_manager:
            self.visualization_manager.cleanup_server()
            
def main():
    """Main entry point."""
    trainer = NixOSModelTrainer(
        start_visualizer=True,
        visualizer_network_access=False
    )
    
    try:
        trainer.setup()
        trainer.train()
    finally:
        trainer.cleanup()
        
if __name__ == "__main__":
    main()
