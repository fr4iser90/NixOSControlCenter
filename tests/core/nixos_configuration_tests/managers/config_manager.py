# src/core/nixos_configuration_tests/managers/config_manager.py
from pathlib import Path
from typing import Tuple
from ..handlers.nixos_config_validator import ConfigValidator
from ..handlers.nixos_config_builder import NixConfigBuilder
from ..handlers.summary_handler import NixConfigErrorHandler, SummaryHandler

class ConfigManager:
    """Orchestriert NixOS Konfigurationstests"""
    
    def __init__(self, test_env_path: Path):
        self.test_env_path = test_env_path
        self.current_test = None
        self.validator = ConfigValidator(test_env_path)
        self.builder = NixConfigBuilder()
    
    def set_current_test(self, test_name: str) -> None:
        """Setzt den Namen des aktuellen Tests"""
        self.current_test = test_name
        
    def apply_config(self, config_content: str):
        """Wendet eine Testkonfiguration an"""
        env_file = self.test_env_path / "env.nix"
        env_file.write_text(config_content)
    
    def validate_config(self) -> Tuple[bool, str]:
        """Delegiert Validierung an den Validator"""
        is_valid, error = self.validator.validate_config(self.test_env_path)
        if not is_valid:
            error = NixConfigErrorHandler.format_error(error, self.current_test or "unknown_test")
        return is_valid, error

    def build_config(self) -> Tuple[bool, str]:
        """Delegiert Build an den Builder"""
        success, error = self.builder.build_config(self.test_env_path)
        if not success:
            error = NixConfigErrorHandler.format_error(error, self.current_test or "unknown_test")
        return success, error
