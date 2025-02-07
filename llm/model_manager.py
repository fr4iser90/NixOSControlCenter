#!/usr/bin/env python3
"""Model Manager for LLM Training Center."""
import warnings
import argparse
import logging
from pathlib import Path

# Import and setup paths first
from scripts.utils.path_config import ProjectPaths
ProjectPaths.setup_python_path()

from scripts.model.model_info import ModelInfo
from scripts.model.training_controller import TrainingController
from scripts.model.evaluation import ModelEvaluator
from scripts.monitoring.resource_monitor import ResourceMonitor

# Filter warnings
warnings.filterwarnings('ignore', category=FutureWarning)

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ModelManager:
    """Manages model operations, training, and evaluation."""
    
    def __init__(self, test_mode: bool = False):
        """Initialize with optional test mode."""
        # Use centralized paths
        self.models_dir = ProjectPaths.MODELS_DIR
        self.test_mode = test_mode
        
        # Initialize components
        self.resource_monitor = ResourceMonitor(self.models_dir)
        self.model_info = ModelInfo(self.models_dir)
        self.training_controller = TrainingController(self.models_dir, test_mode)
        self.evaluator = ModelEvaluator(self.models_dir)
        
    def get_model_overview(self, model_name: str):
        """Get comprehensive model overview including history and metrics."""
        return self.model_info.get_model_overview(model_name)
        
    def list_checkpoints(self, model_name=None):
        """List all available checkpoints for a model."""
        return self.model_info.list_checkpoints(model_name)
        
    def get_model_info(self):
        """Get detailed information about available models and checkpoints."""
        return self.model_info.get_model_info()
        
    def get_available_models(self):
        """Get list of available trained models."""
        return self.model_info.get_available_models()
        
    def start_training(self):
        """Start or continue model training."""
        self.training_controller.start_training()
        
    def start_fresh_training(self):
        """Start fresh training with default model."""
        self.training_controller.start_fresh_training()
        
    def evaluate_model(self, model_name, test_dataset=None, checkpoint=None):
        """Evaluate model performance with detailed metrics."""
        return self.evaluator.evaluate_model(model_name, test_dataset, checkpoint)
        
    def explain_prediction(self, model_name, text, checkpoint=None):
        """Generate model interpretation for a prediction."""
        return self.evaluator.explain_prediction(model_name, text, checkpoint)

def main():
    """Main entry point with argument parsing."""
    parser = argparse.ArgumentParser(description='NixOS Model Manager')
    parser.add_argument('--test', action='store_true', help='Run in test mode')
    parser.add_argument('--trainer-type', choices=['base', 'lora', 'feedback'], 
                       default='lora', help='Type of trainer to use')
    parser.add_argument('--visualize', action='store_true', 
                       help='Start visualization server')
    parser.add_argument('--network-access', action='store_true',
                       help='Allow network access to visualization')
    args = parser.parse_args()
    
    manager = ModelManager(test_mode=args.test)
    manager.training_controller.trainer_type = args.trainer_type
    manager.training_controller.start_visualizer = args.visualize
    manager.training_controller.visualizer_network_access = args.network_access
    manager.start_training()

if __name__ == "__main__":
    main()
