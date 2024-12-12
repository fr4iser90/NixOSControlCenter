from pathlib import Path
import subprocess
from typing import Tuple
import os
import logging

# Logger Setup
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)  # Change to INFO as default level

class NixConfigBuilder:
    """Executes NixOS build operations"""
    
    def __init__(self):
        self.nix_cmd = "nix"
        logger.debug("NixConfigBuilder initialized")
    
    def build_config(self, config_path: Path) -> Tuple[bool, str]:
        """Builds the NixOS configuration"""
        try:
            # Detailed debugging information
            logger.debug(f"Current directory: {os.getcwd()}")
            logger.debug(f"Target config directory: {config_path}")
            logger.debug(f"Files in target: {list(config_path.glob('*'))}")
            
            # Important operations as INFO
            original_dir = os.getcwd()
            os.chdir(str(config_path))
            logger.info(f"Building configuration in: {os.getcwd()}")
            
            result = subprocess.run(
                [
                    self.nix_cmd, "build",
                    f"path:{config_path}#nixosConfigurations.testhost.config.system.build.toplevel",
                    "--no-link",
                    "--dry-run",
                    "--impure",
                    "--accept-flake-config"
                ],
                capture_output=True,
                text=True,
                timeout=60,
                env={
                    **os.environ,
                    "NO_UPDATE_LOCK_FILE": "1"
                }
            )
            
            # Debug output only if needed
            if logger.isEnabledFor(logging.DEBUG):
                logger.debug(f"Command stdout: {result.stdout}")
                logger.debug(f"Command stderr: {result.stderr}")
                logger.debug(f"Return code: {result.returncode}")
            
            if result.returncode == 0:
                logger.info("Configuration build successful")
            else:
                logger.error(f"Build failed: {result.stderr}")
                
            return result.returncode == 0, result.stderr
            
        except Exception as e:
            logger.exception("Unexpected error during build")
            return False, str(e)
        finally:
            if 'original_dir' in locals():
                logger.debug(f"Restoring original directory: {original_dir}")
                os.chdir(original_dir)