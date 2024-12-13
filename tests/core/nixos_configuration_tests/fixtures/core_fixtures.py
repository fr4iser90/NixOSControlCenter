"""
Core fixtures for basic test setup and configuration.
"""

import pytest
from pathlib import Path

@pytest.fixture(scope="session")
def project_root():
    """Returns the project root directory"""
    return Path(__file__).parent.parent.parent

@pytest.fixture(scope="session")
def test_root():
    """Returns the NixOS tests directory"""
    return Path(__file__).parent.parent

@pytest.fixture(scope="session")
def temp_dir(test_root):
    """Provides and manages a temporary directory for tests"""
    tmp = test_root / "tmp"
    tmp.mkdir(exist_ok=True, parents=True)  # parents=True ist wichtig!
    return tmp

@pytest.fixture(scope="session")
def config_generator():
    """Provides the NixOS environment generator"""
    from core.nixos_configuration_tests.handlers.nixos_config_generator import NixOSEnvGenerator
    return NixOSEnvGenerator()

@pytest.fixture(scope="session")
def config_validator():
    """Provides the NixOS configuration validator"""
    from core.nixos_configuration_tests.handlers.nixos_config_validator import NixOSConfigValidator
    return NixOSConfigValidator() 