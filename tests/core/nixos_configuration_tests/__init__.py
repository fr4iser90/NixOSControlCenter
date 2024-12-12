"""
NixOS Configuration Test Handlers
================================

This package contains the core handlers for testing NixOS configurations.

Core Components:
---------------

NixConfigBuilder:
    Handles NixOS configuration build operations.
    
    This class provides functionality to build and test NixOS configurations
    in a controlled environment. It supports dry-run builds and handles
    directory management during the build process.
    
    Methods:
        build_config(config_path: Path) -> Tuple[bool, str]:
            Builds a NixOS configuration using nix-build.
            Returns success status and error message if any.

ConfigValidator:
    Validates NixOS configurations for correctness.
    
    Provides validation functionality for NixOS configurations by evaluating
    the configuration files and checking for syntax and semantic errors.
    Supports both flake and traditional configurations.
    
    Methods:
        validate_config() -> Tuple[bool, str]:
            Validates the NixOS configuration using nix-eval.
            Returns validation status and error message if any.

EnvironmentHandler:
    Manages isolated test environments for NixOS configurations.
    
    Creates and manages temporary test environments for safely testing
    NixOS configurations. Handles file copying, environment setup,
    and cleanup operations.
    
    Methods:
        setup_test_env() -> Path:
            Creates a new isolated test environment.
            Returns path to the created environment.
            
        apply_test_config(config_content: str):
            Applies a test configuration to the current environment.
            
        validate_config() -> Tuple[bool, str]:
            Validates the current environment's configuration.
            
        build_config() -> Tuple[bool, str]:
            Builds the configuration in the current environment.
            
        cleanup():
            Removes the test environment and all its contents.

ConfigGenerator:
    Generates NixOS configurations based on provided parameters.
    
    Creates complete NixOS configurations from a set of parameters,
    handling all necessary module imports and configuration options.
    Supports various system profiles and hardware configurations.
    
    Methods:
        generate_config(**kwargs) -> str:
            Generates a complete NixOS configuration from the provided parameters.
            Returns the generated configuration as a string.
            
        Supported parameters include:
            - systemType: Type of system (desktop, server, etc.)
            - bootloader: Bootloader configuration
            - mainUser: Primary user account
            - hostName: System hostname
            - timeZone: System timezone
            - locales: System locales
            - keyboardLayout: Keyboard configuration
            - desktop: Desktop environment
            - displayManager: Display manager
            - gpu: Graphics configuration
            - audio: Audio system configuration
"""

from .handlers.nixos_config_builder import NixConfigBuilder
from .handlers.nixos_config_validator import ConfigValidator
from .handlers.environment_handler import EnvironmentHandler
from .handlers.nixos_config_generator import ConfigGenerator

__all__ = [
    'NixConfigBuilder',
    'ConfigValidator',
    'EnvironmentHandler',
    'ConfigGenerator'
]