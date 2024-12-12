from pathlib import Path
import subprocess
from typing import Optional, Tuple

class ConfigValidator:
    """Validiert NixOS Konfigurationen"""
    
    def __init__(self):
        self.nix_cmd = "nix"
    
    def validate(self, config_path: Path) -> Tuple[bool, Optional[str]]:
        """Validiert eine Konfiguration"""
        try:
            # Prüfe Flake
            flake_check = subprocess.run(
                [self.nix_cmd, "flake", "check"],
                cwd=config_path,
                capture_output=True,
                text=True
            )
            if flake_check.returncode != 0:
                return False, f"Flake check failed:\n{flake_check.stderr}"
            
            # Prüfe Build (dry-run)
            build_check = subprocess.run(
                [
                    self.nix_cmd, 
                    "build", 
                    ".#nixosConfigurations.testhost.config.system.build.toplevel",
                    "--dry-run"
                ],
                cwd=config_path,
                capture_output=True,
                text=True
            )
            if build_check.returncode != 0:
                return False, f"Build check failed:\n{build_check.stderr}"
            
            return True, None
            
        except Exception as e:
            return False, f"Validation error: {str(e)}"
    
    def check_syntax(self, nix_file: Path) -> Tuple[bool, Optional[str]]:
        """Prüft die Nix-Syntax einer Datei"""
        try:
            result = subprocess.run(
                [self.nix_cmd, "eval", "--expr", f"import {nix_file}"],
                capture_output=True,
                text=True
            )
            return result.returncode == 0, result.stderr if result.returncode != 0 else None
        except Exception as e:
            return False, f"Syntax check error: {str(e)}"
    
    def evaluate_config(self, config_path: Path) -> Tuple[bool, Optional[str]]:
        """Evaluiert eine Konfiguration vollständig"""
        try:
            result = subprocess.run(
                [
                    self.nix_cmd,
                    "eval",
                    ".#nixosConfigurations.testhost.config",
                    "--json"
                ],
                cwd=config_path,
                capture_output=True,
                text=True
            )
            return result.returncode == 0, result.stderr if result.returncode != 0 else None
        except Exception as e:
            return False, f"Evaluation error: {str(e)}"