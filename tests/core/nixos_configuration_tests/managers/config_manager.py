from pathlib import Path
from typing import Tuple
from ..handlers.nixos_config_validator import NixOSConfigValidator
from ..handlers.nixos_config_builder import NixOSBuildValidator
from ..handlers.summary_handler import NixConfigErrorHandler, SummaryHandler
from .error_manager import ErrorManager

class ConfigManager:
    """Orchestriert NixOS Konfigurationstests"""
    
    def __init__(self, test_env_path: Path):
        self.test_env_path = test_env_path
        self.current_test = None
        self.error_manager = ErrorManager()
        self.validator = NixOSConfigValidator(test_env_path)
        self.builder = NixOSBuildValidator(test_env_path)
    
    def set_current_test(self, test_name: str) -> None:
        """Setzt den Namen des aktuellen Tests"""
        self.current_test = test_name
        # Get error handler from manager
        self.error_handler = self.error_manager.get_handler(test_name)
        # Pass it to builder
        self.builder.error_handler = self.error_handler  # Direkte Zuweisung
        self.validator.current_test = test_name
        self.builder.current_test = test_name
        
    def apply_config(self, config_content: str, test_name: str = None):
        """Wendet eine Testkonfiguration an"""
        if test_name:
            self.set_current_test(test_name)
            
        env_file = self.test_env_path / "env.nix"
        env_file.write_text(config_content)
        
        # Store configs in error handler
        if self.current_test and hasattr(self, 'error_handler'):
            self.error_handler.store_configs(
                test_name=self.current_test,
                python_config=self.validator._current_config if hasattr(self.validator, '_current_config') else {},
                nix_config=config_content
            )
    
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

        return success, error