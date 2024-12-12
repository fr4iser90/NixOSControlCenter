from pathlib import Path
import shutil
import subprocess
import os

class TestEnvironment:
    """Manages isolated test environments for NixOS configurations"""
    
    def __init__(self, test_root: Path):
        # Get path from environment variable
        nixos_config_dir = os.environ.get('NIXOS_CONFIG_DIR')
        if not nixos_config_dir:
            raise RuntimeError("NIXOS_CONFIG_DIR environment variable not set. Are you running in the nix-shell?")
        
        self.nixos_root = Path(nixos_config_dir)
        if not self.nixos_root.exists():
            raise RuntimeError(f"NixOS configuration directory not found at {self.nixos_root}. Did you create src/nixos?")
            
        self.test_root = test_root
        self.current_env = None
    
    def setup_test_env(self) -> Path:
        """Creates a new isolated test environment"""
        # Create unique test directory
        test_id = len(list(self.test_root.glob("test_env_*"))) + 1
        self.current_env = self.test_root / f"test_env_{test_id}"
        self.current_env.mkdir(parents=True, exist_ok=True)
        
        # Copy required files
        for item in ['flake.nix', 'flake.lock', 'env.nix', 'modules', 'hardware-configuration.nix']:
            src = self.nixos_root / item
            dst = self.current_env / item
            if src.exists():
                if src.is_file():
                    shutil.copy2(src, dst)
                elif src.is_dir():
                    shutil.copytree(src, dst, dirs_exist_ok=True)
        
        return self.current_env
    
    def apply_test_config(self, config_content: str):
        """Applies test configuration by writing to env.nix"""
        if not self.current_env:
            raise RuntimeError("Setup test environment first!")
            
        env_file = self.current_env / "env.nix"
        env_file.write_text(config_content)
    
    def validate_config(self) -> tuple[bool, str]:
        """Validates the NixOS configuration"""
        try:
            # Check if required files exist
            if not (self.current_env / "flake.nix").exists():
                return False, "flake.nix not found in test environment"

            # Evaluate the flake directly from filesystem
            result = subprocess.run(
                [
                    "nix", "build", 
                    f"path:{self.current_env}#nixosConfigurations.testhost.config.system.build.toplevel",
                    "--dry-run",
                    "--no-link",
                    "--impure"
                ],
                cwd=self.current_env,
                capture_output=True,
                text=True
            )
            
            return result.returncode == 0, result.stderr
        except Exception as e:
            return False, str(e)
    
    def build_config(self) -> tuple[bool, str]:
        """Builds the configuration (dry-run)"""
        try:
            result = subprocess.run(
                ["nix", "build", ".#nixosConfigurations.testhost.config.system.build.toplevel", "--dry-run"],
                cwd=self.current_env,
                capture_output=True,
                text=True
            )
            return result.returncode == 0, result.stderr
        except Exception as e:
            return False, str(e)
    
    def cleanup(self):
        """Cleans up the test environment"""
        if self.current_env and self.current_env.exists():
            shutil.rmtree(self.current_env)
            self.current_env = None