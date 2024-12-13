from pathlib import Path
from typing import Tuple
import subprocess
import os
import logging

# Configure logging
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

class NixOSConfigValidator:
    """Validates NixOS configurations for correctness"""
    
    def __init__(self, env_path: Path):
        """
        Initialize validator with environment path
        
        Args:
            env_path: Path to the test environment
        """
        self.nix_cmd = "nix"
        self.env_path = env_path
        self.current_test = None  # Für besseres Logging
    
    def set_current_test(self, test_name: str):
        """Sets the current test name for better logging"""
        self.current_test = test_name
        logger.info(f"Setting current test to: {test_name}")
    
    def validate_config(self) -> Tuple[bool, str]:
        """
        Validates the NixOS configuration using nix-eval
        
        Returns:
            Tuple of (success: bool, error_message: str)
        """
        try:
            original_dir = os.getcwd()
            os.chdir(str(self.env_path))
            logger.info(f"Starting configuration validation for test '{self.current_test}' in: {self.env_path}")
            
            # Führe tatsächliche Validierung durch
            result = subprocess.run(
                [
                    self.nix_cmd, "eval",
                    "--impure",
                    "--expr", "import ./flake.nix",
                    "--show-trace"
                ],
                capture_output=True,
                text=True,
                check=True  # Raise CalledProcessError if command fails
            )
                
            if result.returncode != 0:
                logger.error(f"Configuration validation failed for test '{self.current_test}'")
                return False, result.stderr
                
            logger.info(f"Configuration validation successful for test '{self.current_test}'")
            return True, ""
                
        except subprocess.CalledProcessError as e:
            error_msg = f"Validation failed with exit code {e.returncode}: {e.stderr}"
            logger.error(error_msg)
            return False, error_msg
        except Exception as e:
            logger.error(f"Validation error in test '{self.current_test}': {str(e)}")
            return False, str(e)
        finally:
            os.chdir(original_dir)