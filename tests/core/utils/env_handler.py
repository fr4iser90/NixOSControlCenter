from pathlib import Path
import shutil
import subprocess

class TestEnvironment:
    """Verwaltet isolierte Testumgebungen"""
    
    def __init__(self, nixos_root: Path = Path("/etc/nixos")):
        self.nixos_root = nixos_root
        self.test_root = Path("tests/tmp")
        self.current_env = None
    
    def setup_test_env(self) -> Path:
        """Erstellt eine neue isolierte Testumgebung"""
        # Erstelle eindeutigen Test-Ordner
        test_id = len(list(self.test_root.glob("test_env_*"))) + 1
        self.current_env = self.test_root / f"test_env_{test_id}"
        self.current_env.mkdir(parents=True, exist_ok=True)
        
        # Kopiere wichtige Dateien
        for file in ['flake.nix', 'flake.lock', 'modules', 'profiles']:
            src = self.nixos_root / file
            dst = self.current_env / file
            if src.is_file():
                shutil.copy2(src, dst)
            elif src.is_dir():
                shutil.copytree(src, dst, dirs_exist_ok=True)
        
        return self.current_env
    
    def apply_test_config(self, config_content: str):
        """Wendet Test-Konfiguration an"""
        if not self.current_env:
            raise RuntimeError("Setup test environment first!")
            
        env_file = self.current_env / "env.nix"
        env_file.write_text(config_content)
    
    def validate_config(self) -> tuple[bool, str]:
        """Validiert die Konfiguration"""
        try:
            result = subprocess.run(
                ["nix", "flake", "check"],
                cwd=self.current_env,
                capture_output=True,
                text=True
            )
            return result.returncode == 0, result.stderr
        except Exception as e:
            return False, str(e)
    
    def build_config(self) -> tuple[bool, str]:
        """Baut die Konfiguration"""
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
        """Räumt die Testumgebung auf"""
        if self.current_env and self.current_env.exists():
            shutil.rmtree(self.current_env)
            self.current_env = None