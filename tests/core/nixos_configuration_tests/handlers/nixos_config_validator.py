from pathlib import Path
from typing import Tuple
import subprocess
import os
import logging

# Logger Setup
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)  # Ändern auf INFO als Standard-Level

class ConfigValidator:
    """Validiert NixOS Konfigurationen"""
    
    def __init__(self, env_path: Path):
        self.nix_cmd = "nix"
        self.env_path = env_path
        logger.debug(f"Validator initialized with env_path: {env_path}")
    
    def validate_config(self) -> Tuple[bool, str]:
        """Validiert die NixOS Konfiguration"""
        try:
            # Detaillierte Debugging-Informationen
            logger.debug(f"Current directory: {os.getcwd()}")
            logger.debug(f"Target config directory: {self.env_path}")
            logger.debug(f"Files in target: {list(self.env_path.glob('*'))}")
            
            # Wichtige Operationen als INFO
            original_dir = os.getcwd()
            os.chdir(str(self.env_path))
            logger.info(f"Validating configuration in: {os.getcwd()}")
            
            result = subprocess.run(
                [
                    self.nix_cmd, "eval",
                    "--impure",
                    "--expr", "import ./flake.nix",
                    "--show-trace"
                ],
                capture_output=True,
                text=True
            )
            
            # Debug-Output nur wenn nötig
            if logger.isEnabledFor(logging.DEBUG):
                logger.debug(f"Command stdout: {result.stdout}")
                logger.debug(f"Command stderr: {result.stderr}")
                logger.debug(f"Return code: {result.returncode}")
                
            if result.returncode != 0:
                logger.error(f"Validation failed: {result.stderr}")
                return False, result.stderr
                
            logger.info("Configuration validation successful")
            return True, ""
                
        except Exception as e:
            logger.exception("Unexpected error during validation")
            return False, str(e)
        finally:
            if 'original_dir' in locals():
                logger.debug(f"Restoring original directory: {original_dir}")
                os.chdir(original_dir)