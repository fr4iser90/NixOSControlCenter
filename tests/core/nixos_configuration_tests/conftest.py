"""
Main pytest configuration file for NixOS configuration tests.
Centralizes all test dependencies, fixtures and hooks.
"""

import pytest
from pathlib import Path
from typing import Optional

def pytest_addoption(parser):
    """
    Adds custom command line options for test execution.
    """
    parser.addoption(
        "--show-progress", 
        action="store_true", 
        help="Show progress bar during tests"
    )
    
    parser.addoption(
        "--test-strategy",
        choices=["validate-only", "full"],
        default="validate-only",
        help="Test strategy: validate-only or full (validate + build)"
    )

# Core component imports
from .managers.config_manager import ConfigManager
from .handlers.environment_handler import NixOSTestEnvironment
from .handlers.nixos_config_generator import NixOSEnvGenerator
from .handlers.nixos_config_validator import NixOSConfigValidator
from .handlers.nixos_config_builder import NixOSBuildValidator
from .handlers.summary_handler import (
    NixConfigErrorHandler, 
    SummaryHandler
)

# Import all test fixtures and hooks
from .fixtures.core_fixtures import *
from .fixtures.env_fixtures import *
from .fixtures.test_fixtures import *
from .fixtures.output_hooks import *
from .fixtures.reporting_hooks import *
from .fixtures.session_hooks import *

# Initialize test session
from .utils.session_manager import SessionManager
session = SessionManager()

# Test -> auto_environment -> NixOSTestEnvironment -> ConfigManager -> Validator/Builder