from pathlib import Path
from typing import Tuple
from ..handlers.nixos_config_validator import NixOSConfigValidator
from ..handlers.nixos_config_builder import NixOSBuildValidator
from ..handlers.summary_handler import NixConfigErrorHandler, SummaryHandler

class ConfigManager:
    """Orchestriert NixOS Konfigurationstests"""
    
    def __init__(self, test_env_path: Path):
        self.test_env_path = test_env_path
        self.current_test = None
        self.validator = NixOSConfigValidator(test_env_path)
        self.builder = NixOSBuildValidator(test_env_path)
    
    def set_current_test(self, test_name: str) -> None:
        """Setzt den Namen des aktuellen Tests"""
        self.current_test = test_name
        # Setze auch für Validator und Builder den aktuellen Test
        self.validator.current_test = test_name
        self.builder.current_test = test_name
        
    def apply_config(self, config_content: str, test_name: str = None):
        """Wendet eine Testkonfiguration an"""
        if test_name:
            self.set_current_test(test_name)
            
        env_file = self.test_env_path / "env.nix"
        env_file.write_text(config_content)
    
    def validate_config(self) -> Tuple[bool, str]:
        """Delegiert Validierung an den Validator"""
        if self.current_test:
            self.validator.set_current_test(self.current_test)
        is_valid, error = self.validator.validate_config()
        if not is_valid:
            error = NixConfigErrorHandler.format_error(error, self.current_test or "unknown_test")
        return is_valid, error

    def build_config(self) -> Tuple[bool, str]:
        """Delegiert Build an den Builder"""
        if self.current_test:
            self.builder.set_current_test(self.current_test)
        self.builder.set_env_path(self.test_env_path)
        print(f"\nExecuting build for test: {self.current_test}")
        success, error = self.builder.build_config()
        if not success:
            error = NixConfigErrorHandler.format_error(error, self.current_test or "unknown_test")
        return success, error