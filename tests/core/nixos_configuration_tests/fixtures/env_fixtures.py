"""
Environment-related fixtures for NixOS configuration testing.
Handles test environment setup, validation, and cleanup.
"""

import os
import pytest
import time
from pathlib import Path
from ..handlers.environment_handler import NixOSTestEnvironment

@pytest.fixture(scope="session")
def test_environment(temp_dir, request):
    """
    Sets up the test environment with NixOS configuration directory validation.
    
    Validates:
    - NIXOS_CONFIG_DIR environment variable
    - Required configuration files
    - Module directory structure
    """
    # Get test strategy from command line
    test_strategy = request.config.getoption("--test-strategy")
    
    nixos_config_dir = os.environ.get('NIXOS_CONFIG_DIR')
    if not nixos_config_dir:
        raise RuntimeError("NIXOS_CONFIG_DIR environment variable is not set!")
        
    nixos_config_path = Path(nixos_config_dir)
    if not nixos_config_path.exists():
        raise RuntimeError(f"NIXOS_CONFIG_DIR path does not exist: {nixos_config_dir}")
    
    # Verify required files exist
    required_files = ['flake.nix', 'flake.lock', 'hardware-configuration.nix']
    missing_files = [f for f in required_files if not (nixos_config_path / f).exists()]
    if missing_files:
        raise RuntimeError(f"Missing required files in {nixos_config_dir}: {missing_files}")
        
    # Verify modules directory exists
    modules_path = nixos_config_path / "modules"
    if not modules_path.exists() or not modules_path.is_dir():
        raise RuntimeError(f"Modules directory not found at {modules_path}")    
    
    # Pass test_strategy to NixOSTestEnvironment
    return NixOSTestEnvironment(temp_dir, test_strategy=test_strategy)

@pytest.fixture
def auto_environment(test_environment, request):
    """
    Provides a fresh test environment for each test.
    Handles setup and cleanup automatically.
    """
    try:
        test_strategy = request.config.getoption("--test-strategy")
        test_environment.test_strategy = test_strategy
        env = test_environment.setup_test_environment()
        yield test_environment
    finally:
        time.sleep(10.5)
        test_environment.cleanup()

@pytest.fixture(autouse=True)
def setup_test_name(request, auto_environment):
    """
    Automatically sets the current test name in the environment.
    This fixture runs for every test automatically.
    """
    test_name = request.node.name
    auto_environment.config_manager.set_current_test(test_name)
    yield
 