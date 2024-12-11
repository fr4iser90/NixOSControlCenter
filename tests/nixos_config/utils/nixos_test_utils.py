import subprocess
from typing import Optional
from pathlib import Path
import os
import shutil

class NixOSTestEnv:
    def __init__(self):
        self.project_root = Path('/home/fr4iser/Documents/Projects/NixOsControlCenter')
        self.nixos_config_dir = self.project_root / 'src/nixos'
        self.nix = self._find_nix()
        
    def _find_nix(self) -> str:
        """Findet den Pfad zu nix"""
        nix_path = shutil.which('nix')
        if not nix_path:
            raise RuntimeError("nix nicht gefunden")
        return nix_path

    def setup_test_env(self):
        """Bereitet Testumgebung vor"""
        env = os.environ.copy()
        return env

    def run_nix_command(self, *args) -> subprocess.CompletedProcess:
        """Führt einen Nix-Befehl aus"""
        cmd = [self.nix] + list(args)
        return subprocess.run(
            cmd,
            cwd=str(self.nixos_config_dir),
            check=False,
            capture_output=True,
            text=True,
            env=self.setup_test_env()
        )

    def validate_config(self, env_content: Optional[str] = None) -> Optional[str]:
        """Validiert die NixOS-Konfiguration"""
        try:
            if env_content is not None:
                # Schreibe temporäre env.nix
                with open(self.nixos_config_dir / 'env.nix', 'w') as f:
                    f.write(env_content)

            # Baue die Konfiguration, aber installiere sie nicht
            result = subprocess.run(
                ['nix', 'build', '.#nixosConfigurations.testhost.config.system.build.toplevel', '--dry-run'],
                cwd=str(self.nixos_config_dir),
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                return result.stderr
            return None
            
        except Exception as e:
            return str(e)

def validate_config(env_content: Optional[str] = None, test_env: Optional[NixOSTestEnv] = None) -> Optional[str]:
    """Wrapper für die Validierungsfunktion"""
    if test_env is None:
        test_env = NixOSTestEnv()
    return test_env.validate_config(env_content)