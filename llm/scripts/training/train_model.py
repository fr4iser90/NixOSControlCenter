#!/usr/bin/env python3
"""Main training script for NixOS model."""
import logging
from pathlib import Path
from typing import Optional, Union, Dict, Any

from ..utils.path_config import ProjectPaths
from ..data.dataset_manager import DatasetManager
from ..data.dataset_improver import DatasetImprover

from .modules.model_management import ModelInitializer
from .modules.dataset_management import DatasetLoader
from .modules.training import TrainingManager
from .modules.visualization import VisualizationManager
from .modules.feedback import FeedbackManager
from .modules.model_interpretation import ModelInterpreter
from .modules.trainer_factory import TrainerFactory

import click

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@click.group()
def cli():
    """NixOS AI model training CLI."""
    pass

@cli.group()
def base():
    """Manage base models."""
    pass

@base.command()
def list():
    """List downloaded base models."""
    try:
        controller = TrainingController(ProjectPaths())
        models = controller.list_base_models()
        
        if not models:
            click.echo("No base models downloaded yet.")
            return
            
        click.echo("\nDownloaded base models:")
        active_model = controller.get_active_base_model()
        
        for model in models:
            active_marker = "* " if model["name"] == active_model else "  "
            click.echo(f"{active_marker}{model['name']}")
            click.echo(f"   Description: {model['description']}")
            click.echo(f"   Path: {model['local_path']}")
            click.echo()
            
    except Exception as e:
        logger.error(f"Failed to list models: {e}")
        raise

@base.command()
@click.argument("query", required=False)
@click.option("--min-likes", default=50, help="Minimum number of likes")
def search(query, min_likes):
    """Search for available base models."""
    try:
        controller = TrainingController(ProjectPaths())
        models = controller.search_base_models(query=query or "", min_likes=min_likes)
        
        if not models:
            click.echo("No models found matching your criteria.")
            return
            
        click.echo("\nAvailable models:")
        for model in models:
            click.echo(f"\nName: {model['name']}")
            if model.get('description'):
                click.echo(f"Description: {model['description']}")
            click.echo(f"Likes: {model['likes']}")
            click.echo(f"Downloads: {model['downloads']}")
            if model.get('tags'):
                click.echo(f"Tags: {', '.join(model['tags'])}")
                
    except Exception as e:
        logger.error(f"Search failed: {e}")
        raise

@base.command()
@click.argument("model_name")
@click.option("--force", is_flag=True, help="Force re-download if exists")
def download(model_name, force):
    """Download a base model."""
    try:
        controller = TrainingController(ProjectPaths())
        if controller.download_base_model(model_name, force=force):
            click.echo(f"Successfully downloaded model: {model_name}")
        else:
            click.echo(f"Failed to download model: {model_name}")
            
    except Exception as e:
        logger.error(f"Download failed: {e}")
        raise

@base.command()
@click.argument("model_name")
def activate(model_name):
    """Set active base model for training."""
    try:
        controller = TrainingController(ProjectPaths())
        controller.set_active_base_model(model_name)
        click.echo(f"Set active base model to: {model_name}")
        
    except Exception as e:
        logger.error(f"Failed to set active model: {e}")
        raise

class LLMHub:
    """Main trainer class orchestrating all components."""
    
    def __init__(
        self,
        model_name_or_path: Union[str, Path] = "facebook/opt-125m",
        start_visualizer: bool = False,
        visualizer_network_access: bool = False,
        trainer_type: str = "lora",
        config: Optional[Dict[str, Any]] = None,
        test_mode: bool = False
    ):
        """Initialize trainer with all necessary components."""
        # Convert Path to string if needed
        self.model_name = str(model_name_or_path)
        self.trainer_type = trainer_type
        self.config = config
        self.test_mode = test_mode
        
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
        self.dataset_manager = DatasetManager()
        self.dataset_loader = DatasetLoader(self.dataset_manager, self.dataset_dir)
        self.feedback_manager = FeedbackManager(DatasetImprover())
        
        # Initialize visualization if requested
        self.start_visualizer = start_visualizer
        self.visualizer_network_access = visualizer_network_access
        self.visualization_manager = None
        
        # Initialize trainer components
        self.trainer = None
        self.model = None
        self.tokenizer = None
        self.initialized = False
        
    def setup(self):
        """Set up all components for training."""
        if self.initialized:
            logger.warning("Trainer already initialized.")
            return
        
        # Initialize visualization if requested
        if self.start_visualizer:
            self.visualization_manager = VisualizationManager(
                ProjectPaths(),
                network_access=self.visualizer_network_access
            )
            self.visualization_manager.start_server()
            
        # Create trainer with factory
        try:
            self.trainer = TrainerFactory.create_trainer(
                trainer_type=self.trainer_type,
                model_path=self.model_name,
                config=self.config,
                dataset_manager=self.dataset_manager,
                visualizer=self.visualization_manager
            )
            self.model = self.trainer.model
            self.tokenizer = self.trainer.tokenizer
            self.initialized = True
        except Exception as e:
            logger.error(f"Failed to initialize trainer: {e}")
            if self.visualization_manager:
                self.visualization_manager.cleanup_server()
            raise
        
    def train(self):
        """Run the training process."""
        if not self.trainer:
            logger.error("Trainer not initialized. Run setup() first.")
            return False
            
        try:
            # Start training
            logger.info("Starting training process...")
            success = self.trainer.train()
            
            if success:
                # Save the model
                self.trainer.save_checkpoints()
                
                # Analyze feedback and improve datasets
                analysis = self.feedback_manager.analyze_feedback()
                if analysis:
                    self.dataset_manager.apply_improvements(analysis)
                    
                # Get model interpretation
                interpretation_results = ModelInterpreter(self.model, self.tokenizer).analyze_errors(
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
            explanation = ModelInterpreter(self.model, self.tokenizer).explain_prediction(text)
            
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
    parser.add_argument('--model-name', type=str, default='facebook/opt-125m',
                       help='Name for the model')
    parser.add_argument('--visualize', action='store_true',
                       help='Start visualization server')
    parser.add_argument('--network-access', action='store_true',
                       help='Allow network access to visualization')
    parser.add_argument('--trainer-type', type=str, default='lora',
                       help='Type of trainer to use')
    parser.add_argument('--config', type=str, default=None,
                       help='Path to trainer config file')
    parser.add_argument('--test', action='store_true',
                       help='Run in test mode')
    
    args = parser.parse_args()
    
    trainer = LLMHub(
        args.model_name,
        start_visualizer=args.visualize,
        visualizer_network_access=args.network_access,
        trainer_type=args.trainer_type,
        config=args.config,
        test_mode=args.test
    )
    
    try:
        trainer.setup()
        trainer.train()
    finally:
        trainer.cleanup()
        
if __name__ == "__main__":
    cli.add_command(base)
    cli()
