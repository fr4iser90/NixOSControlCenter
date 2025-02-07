#!/usr/bin/env python3
"""Main training script for NixOS model."""
import logging
from pathlib import Path
from typing import Optional, Union

from ..utils.path_config import ProjectPaths
from ..data.dataset_manager import DatasetManager
from ..data.dataset_improver import DatasetImprover

from .modules.model_management import ModelInitializer
from .modules.dataset_management import DatasetLoader
from .modules.training import TrainingManager
from .modules.visualization import VisualizationManager
from .modules.feedback import FeedbackManager
from .modules.model_interpretation import ModelInterpreter

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class NixOSModelTrainer:
    """Main trainer class orchestrating all components."""
    
    def __init__(
        self,
        model_name_or_path: Union[str, Path] = "NixOS",
        start_visualizer: bool = False,
        visualizer_network_access: bool = False,
        test_mode: bool = False
    ):
        """Initialize trainer with all necessary components."""
        # Convert Path to string if needed
        self.model_name = str(model_name_or_path)
        
        # Initialize paths
        ProjectPaths.ensure_directories()
        
        # Handle checkpoint paths
        if isinstance(model_name_or_path, Path) and model_name_or_path.exists():
            self.output_dir = model_name_or_path
            # Extract model name from checkpoint path
            parent_dir = model_name_or_path.parent
            if parent_dir.name.startswith("checkpoint-"):
                self.model_name = parent_dir.parent.name
            else:
                self.model_name = parent_dir.name
        else:
            self.output_dir = ProjectPaths.MODELS_DIR / self.model_name
            
        self.dataset_dir = str(ProjectPaths.DATASET_DIR)
        
        # Initialize components
        self.model_initializer = ModelInitializer(ProjectPaths)
        self.dataset_manager = DatasetManager()
        self.dataset_loader = DatasetLoader(self.dataset_manager, self.dataset_dir)
        self.training_manager = TrainingManager(self.model_name, self.output_dir, test_mode=test_mode)
        self.visualization_manager = VisualizationManager(
            ProjectPaths,
            visualizer_network_access
        ) if start_visualizer else None
        self.feedback_manager = FeedbackManager(DatasetImprover())
        
        # Initialize model components
        self.model = None
        self.tokenizer = None
        self.trainer = None
        
        # Initialize model interpreter
        self.model_interpreter = None
        
        self.test_mode = test_mode
        
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
        
        # Initialize model interpreter
        self.model_interpreter = ModelInterpreter(self.model, self.tokenizer)
        
        # Load datasets
        logger.info("Loading and preparing datasets...")
        if self.test_mode:
            train_dataset, eval_dataset = self.dataset_loader.load_test_dataset()
        else:
            train_dataset, eval_dataset = self.dataset_loader.load_and_validate_processed_datasets()
        
        # Initialize trainer with processing_class instead of tokenizer
        logger.info("Setting up trainer...")
        self.trainer = self.training_manager.initialize_trainer(
            model=self.model,
            train_dataset=train_dataset,
            eval_dataset=eval_dataset,
            processing_class=self.tokenizer.__class__,  # Use processing_class instead of tokenizer
            tokenizer=self.tokenizer  # Keep for backward compatibility
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
                    self.dataset_manager.apply_improvements(analysis)
                    
                # Get model interpretation
                interpretation_results = self.model_interpreter.analyze_errors(
                    self.dataset_loader.load_test_data()
                )
                
                # Save interpretation results
                interpretation_path = self.output_dir / "interpretation_results.json"
                import json
                with open(interpretation_path, 'w') as f:
                    json.dump(interpretation_results, f, indent=2)
                
                logger.info(f"Training completed. Model saved to {self.output_dir}")
                logger.info(f"Interpretation results saved to {interpretation_path}")
                
                return True
        except Exception as e:
            logger.error(f"Error during training: {e}")
            
        return False
        
    def explain_prediction(self, text: str):
        """Generate explanation for a single prediction."""
        try:
            explanation = self.model_interpreter.explain_prediction(text)
            
            # Save explanation
            explanations_dir = self.output_dir / "explanations"
            explanations_dir.mkdir(exist_ok=True)
            
            explanation_path = explanations_dir / f"explanation_{hash(text)}.json"
            import json
            with open(explanation_path, 'w') as f:
                json.dump(explanation, f, indent=2)
            
            logger.info(f"Explanation saved to {explanation_path}")
            
            return explanation
            
        except Exception as e:
            logger.error(f"Explanation failed: {str(e)}")
            raise

    def cleanup(self):
        """Clean up resources."""
        if hasattr(self, 'visualization_manager'):
            self.visualization_manager.cleanup_server()

def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Train NixOS model')
    parser.add_argument('--model-name', type=str, default='NixOS',
                       help='Name for the model')
    parser.add_argument('--visualize', action='store_true',
                       help='Start visualization server')
    parser.add_argument('--network-access', action='store_true',
                       help='Allow network access to visualization')
    parser.add_argument('--test', action='store_true',
                       help='Run in test mode')
    
    args = parser.parse_args()
    
    trainer = NixOSModelTrainer(
        args.model_name,
        start_visualizer=args.visualize,
        visualizer_network_access=args.network_access,
        test_mode=args.test
    )
    
    try:
        trainer.setup()
        trainer.train()
    finally:
        trainer.cleanup()
        
if __name__ == "__main__":
    main()
