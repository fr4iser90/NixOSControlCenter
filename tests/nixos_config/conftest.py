# tests/nixos_config/conftest.py
import pytest
import os
from tests.nixos_config.utils.config_generator import NixOSConfigGenerator

@pytest.fixture(scope="session")
def config_generator():
    return NixOSConfigGenerator()

@pytest.fixture(scope="session")
def nixos_root():
    return "/etc/nixos"

@pytest.fixture(autouse=True)
def backup_env(nixos_root):
    """Automatisches Backup der env.nix"""
    env_path = os.path.join(nixos_root, "env.nix")
    backup_path = env_path + ".backup"
    
    if os.path.exists(env_path):
        with open(env_path, 'r') as f:
            original = f.read()
        with open(backup_path, 'w') as f:
            f.write(original)
    
    yield
    
    if os.path.exists(backup_path):
        with open(backup_path, 'r') as f:
            original = f.read()
        with open(env_path, 'w') as f:
            f.write(original)
        os.remove(backup_path)