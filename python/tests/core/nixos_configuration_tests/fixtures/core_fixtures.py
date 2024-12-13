"""
Core fixtures for basic test setup and configuration.
"""

import os
import pytest
from pathlib import Path

@pytest.fixture(scope="session")
def python_root():
    """Returns the Python root directory from environment"""
    return Path(os.environ["PYTHON_ROOT"])

@pytest.fixture(scope="session")
def nixos_config_dir():
    """Returns the NixOS config directory from environment"""
    return Path(os.environ["PYTHON_NIXOS_CONFIG_DIR"])

@pytest.fixture(scope="session")
def test_tmp_dir():
    """Returns the test temp directory from environment"""
    tmp_dir = Path(os.environ["PYTHON_TEST_TMP_DIR"])
    tmp_dir.mkdir(exist_ok=True, parents=True)
    return tmp_dir

@pytest.fixture(scope="session")
def test_log_dir():
    """Returns the test log directory from environment"""
    log_dir = Path(os.environ["PYTHON_TEST_LOG_DIR"])
    log_dir.mkdir(exist_ok=True, parents=True)
    return log_dir

@pytest.fixture(scope="session")
def config_generator():
    """Provides the NixOS environment generator"""
    from core.nixos_configuration_tests.handlers.nixos_config_generator import NixOSEnvGenerator
    return NixOSEnvGenerator()

@pytest.fixture(scope="session")
def config_validator(nixos_config_dir):
    """Provides the NixOS configuration validator"""
    from core.nixos_configuration_tests.handlers.nixos_config_validator import NixOSConfigValidator
    return NixOSConfigValidator(env_path=nixos_config_dir) 