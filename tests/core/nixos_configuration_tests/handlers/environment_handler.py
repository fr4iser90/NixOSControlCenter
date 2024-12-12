from pathlib import Path
import shutil
import os
from typing import Tuple
from .nixos_config_validator import ConfigValidator
from .nixos_config_builder import NixConfigBuilder
from ..managers.config_manager import ConfigManager

class EnvironmentHandler:
    """Manages isolated test environments"""
    
    def __init__(self, test_root: Path):
        self.nixos_root = Path(os.environ.get('NIXOS_CONFIG_DIR'))
        self.test_root = test_root
        self.current_env = None
        # Initialisiere diese erst wenn wir eine Test-Umgebung haben
        self.validator = None
        self.builder = NixConfigBuilder()
        self.config_manager = None
        
    def setup_test_env(self) -> Path:
        """Creates a new isolated test environment"""
        print(f"\nDEBUG: NIXOS_CONFIG_DIR = {self.nixos_root}")
        print(f"DEBUG: Files in NIXOS_CONFIG_DIR: {list(self.nixos_root.glob('*'))}")
        print(f"DEBUG: Current working directory: {os.getcwd()}")
        
        test_id = len(list(self.test_root.glob("test_env_*"))) + 1
        self.current_env = self.test_root / f"test_env_{test_id}"
        self.current_env.mkdir(parents=True, exist_ok=True)
        
        print(f"DEBUG: Test environment path: {self.current_env}")
        print(f"DEBUG: Test environment exists: {self.current_env.exists()}")

        self.validator = ConfigValidator(self.current_env)
        self.config_manager = ConfigManager(self.current_env)
        # Copy required files
        required_files = ['flake.nix', 'flake.lock', 'hardware-configuration.nix', 'env.nix']
        for file in required_files:
            src = self.nixos_root / file
            dst = self.current_env / file
            print(f"\nCopying {file}:")
            print(f"  From: {src}")
            print(f"  To: {dst}")
            print(f"  Source exists: {src.exists()}")
            if src.exists():
                try:
                    shutil.copy2(src, dst)
                    print(f"  ✓ Copied successfully")
                    # Verify file content
                    with open(dst, 'r') as f:
                        content = f.read()
                        print(f"  Content length: {len(content)} bytes")
                        print(f"  First 100 chars: {content[:100]}")
                except Exception as e:
                    print(f"  ✗ Copy failed: {str(e)}")
            print(f"  Destination exists: {dst.exists()}")
            print(f"  Destination is file: {dst.is_file() if dst.exists() else False}")
        
        # Copy modules directory
        modules_src = self.nixos_root / "modules"
        modules_dst = self.current_env / "modules"
        print(f"\nCopying modules directory:")
        print(f"  From: {modules_src}")
        print(f"  To: {modules_dst}")
        print(f"  Source exists: {modules_src.exists()}")
        if modules_src.exists():
            try:
                shutil.copytree(modules_src, modules_dst, dirs_exist_ok=True)
                print(f"  ✓ Copied successfully")
                # List copied modules
                print(f"  Copied modules: {list(modules_dst.glob('*'))}")
            except Exception as e:
                print(f"  ✗ Copy failed: {str(e)}")
        
        self.config_manager = ConfigManager(self.current_env)
        
        # Final verification
        print("\nFinal environment check:")
        print(f"Files in test environment: {list(self.current_env.glob('*'))}")
        
        return self.current_env
    
    def apply_test_config(self, config_content: str):
        """Applies test configuration directly"""
        if not self.current_env:
            raise RuntimeError("Setup test environment first!")
        env_file = self.current_env / "env.nix"
        env_file.write_text(config_content)

    def build_config(self) -> Tuple[bool, str]:
        """Forwards build to the builder directly"""
        if not self.current_env:
            raise RuntimeError("Setup test environment first!")
        return self.builder.build_config(self.current_env)
    
    def validate_config(self) -> Tuple[bool, str]:
        """Forwards validation to the validator directly"""
        if not self.current_env:
            raise RuntimeError("Setup test environment first!")
        return self.validator.validate_config()
      
    def cleanup(self):
        """Cleans up the test environment"""
        if self.current_env and self.current_env.exists():
            shutil.rmtree(self.current_env)
            self.current_env = None
            self.config_manager = None