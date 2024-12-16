from pathlib import Path
import subprocess
from typing import Tuple, Union
import os
import logging
from rich.console import Console
from rich.panel import Panel
from ..handlers.summary_handler import NixConfigErrorHandler, SummaryHandler
import re

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
        self.error_handler = None
    
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
            
            console.print(Panel(
                f"[bold yellow]Building configuration for test:[/bold yellow] {self.current_test}\n"
                f"[cyan]Environment:[/cyan] {self.env_path}",
                title="Build Start"
            ))
            
            result = subprocess.run(
                [
                    self.nix_cmd, "build",
                    f"path:{self.env_path}#nixosConfigurations.testhost.config.system.build.toplevel",
                    "--no-link",
                    "--dry-run",
                    "--impure",
                    "--accept-flake-config",
                ],
                text=True,
                capture_output=True,
                timeout=60,
                env={
                    **os.environ,
                    "NO_UPDATE_LOCK_FILE": "1"
                }
            )
            
            if result.returncode == 0:
                console.print(Panel(
                    "[bold green]✓ Build validation successful[/bold green]",
                    title=f"Build Complete - {self.current_test}"
                ))
                return True, ""
            else:
                error_output = result.stderr or result.stdout
                
                if self.error_handler:
                    self.error_handler.add_error(error_output)
                    error_summary = self.error_handler.get_summary(self.current_test)
                    
                    console.print(Panel(
                        f"[bold red]✗ Build validation failed[/bold red]\n"
                        f"{error_summary}",
                        title=f"Build Failed - {self.current_test}"
                    ))
                
                return False, error_output
                
        except subprocess.TimeoutExpired as e:
            if self.error_handler:
                self.error_handler.add_error(str(e))
            return False, str(e)
        except Exception as e:
            if self.error_handler:
                self.error_handler.add_error(str(e))
            return False, str(e)
        finally:
            os.chdir(original_dir)