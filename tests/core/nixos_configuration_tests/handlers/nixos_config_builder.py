from pathlib import Path
import subprocess
from typing import Tuple
import os
import logging
from rich.console import Console
from rich.panel import Panel

# Configure logging and console
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
console = Console()

class NixOSBuildValidator:
    """Validates NixOS configurations through build testing"""
    
    def __init__(self, env_path: Path = None):
        self.nix_cmd = "nix"
        self.env_path = env_path
        self.current_test = None
    
    def set_current_test(self, test_name: str):
        self.current_test = test_name
    
    def set_env_path(self, env_path: Path):
        self.env_path = env_path
        
    def build_config(self) -> Tuple[bool, str]:
        if not self.env_path:
            return False, "No environment path set"
            
        try:
            original_dir = os.getcwd()
            os.chdir(str(self.env_path))
            
            # Show build start
            console.print(Panel(
                f"[bold yellow]Building configuration for test:[/bold yellow] {self.current_test}\n"
                f"[cyan]Environment:[/cyan] {self.env_path}",
                title="Build Start"
            ))
            
            # Führe Build mit sichtbarer Ausgabe durch
            result = subprocess.run(
                [
                    self.nix_cmd, "build",
                    f"path:{self.env_path}#nixosConfigurations.testhost.config.system.build.toplevel",
                    "--no-link",
                    "--dry-run",
                    "--impure",
                    "--accept-flake-config",
                    "--show-trace",
                ],
                stdout=subprocess.PIPE, 
                capture_output=False,  # Zeige Ausgabe direkt an
                text=True,
                timeout=60,
                env={
                    **os.environ,
                    "NO_UPDATE_LOCK_FILE": "1"
                }
            )
            
            # Show build result
            if result.returncode == 0:
                console.print(Panel(
                    "[bold green]✓ Build validation successful[/bold green]",
                    title=f"Build Complete - {self.current_test}"
                ))
                return True, ""
            else:
                console.print(Panel(
                    "[bold red]✗ Build validation failed[/bold red]",
                    title=f"Build Failed - {self.current_test}"
                ))
                return False, "Build failed"
            
        except subprocess.TimeoutExpired:
            error_msg = f"Build timeout after 60 seconds"
            console.print(Panel(f"[bold red]✗ {error_msg}[/bold red]", title="Build Error"))
            return False, error_msg
        except subprocess.CalledProcessError as e:
            error_msg = f"Build failed with exit code {e.returncode}"
            console.print(Panel(f"[bold red]✗ {error_msg}[/bold red]", title="Build Error"))
            return False, error_msg
        except Exception as e:
            error_msg = f"Build error: {str(e)}"
            console.print(Panel(f"[bold red]✗ {error_msg}[/bold red]", title="Build Error"))
            return False, error_msg
        finally:
            os.chdir(original_dir)