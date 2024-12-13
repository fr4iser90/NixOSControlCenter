from pathlib import Path
import shutil
import os
from typing import Tuple
from .nixos_config_validator import NixOSConfigValidator
from .nixos_config_builder import NixOSBuildValidator
from ..managers.config_manager import ConfigManager
import logging
import tempfile

logger = logging.getLogger(__name__)

class NixOSTestEnvironment:
    """Manages isolated test environments for NixOS configuration testing"""
    
    def __init__(self, test_root: Path, test_strategy: str = "validate-only"):
        """Initialize test environment with root directory"""
        self.nixos_root = Path(os.environ.get('NIXOS_CONFIG_DIR'))
        if not self.nixos_root or not self.nixos_root.exists():
            raise ValueError("NIXOS_CONFIG_DIR environment variable not set or invalid")
            
        self.test_root = test_root
        self.test_strategy = test_strategy
        self.current_environment = None
        self.config_manager = None
        
        logger.info(f"Initialized test environment with strategy: {test_strategy}")
        
    def setup_test_environment(self) -> Path:
        """Creates and sets up a new isolated test environment"""
        # Erstelle ein temporäres Verzeichnis mit eindeutigem Namen
        self._temp_dir = tempfile.mkdtemp(
            prefix="nixos_test_",
            dir=str(self.test_root)
        )
        self.current_environment = Path(self._temp_dir)
        
        logger.info(f"Setting up test environment in: {self.current_environment}")

        # Copy required files
        required_files = ['flake.nix', 'hardware-configuration.nix']
        for file in required_files:
            src = self.nixos_root / file
            dst = self.current_environment / file
            if src.exists():
                shutil.copy2(src, dst)
                logger.debug(f"Copied {file} to test environment")
        
        # Copy modules
        modules_src = self.nixos_root / "modules"
        modules_dst = self.current_environment / "modules"
        if modules_src.exists():
            shutil.copytree(modules_src, modules_dst, dirs_exist_ok=True)
        
        self.config_manager = ConfigManager(self.current_environment)
        return self.current_environment
    
    def apply_test_config(self, config_content: str, test_name: str = None):
        """Applies a test configuration to the environment"""
        if not self.current_environment:
            raise RuntimeError("Test environment not initialized")
        if not self.config_manager:
            raise RuntimeError("Config manager not initialized")
            
        logger.info(f"Applying test configuration: {test_name or 'unnamed'}")
        if test_name:
            self.config_manager.set_current_test(test_name)
        self.config_manager.apply_config(config_content)

    def validate_config(self) -> Tuple[bool, str]:
        """Validates the current configuration"""
        if not self.current_environment:
            raise RuntimeError("Test environment not initialized")
        if not self.config_manager:
            raise RuntimeError("Config manager not initialized")
            
        logger.info("Starting configuration validation")
        return self.config_manager.validate_config()

    def build_config(self) -> Tuple[bool, str]:
        """Executes build test on the current configuration"""
        if not self.current_environment:
            raise RuntimeError("Test environment not initialized")
        if not self.config_manager:
            raise RuntimeError("Config manager not initialized")
            
        if self.test_strategy == "full":
            logger.info("Starting configuration build")
            # Hier ist der wichtige Teil:
            print(f"\nBuilding configuration in {self.current_environment}...")
            success, error = self.config_manager.build_config()
            if not success:
                print(f"\nBuild failed: {error}")
            else:
                print("\nBuild successful!")
            return success, error
        else:
            logger.info("Skipping build (validate-only mode)")
            return True, "Build skipped (validate-only mode)"
      
    def cleanup(self):
        """Removes the test environment and resets state"""
        if self.current_environment and self.current_environment.exists():
            logger.info(f"Cleaning up test environment: {self.current_environment}")
            shutil.rmtree(self.current_environment)
            self.current_environment = None
            self.config_manager = None