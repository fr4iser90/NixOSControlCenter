# tests/nixos_config/test_configurations.py
import pytest
from .utils.nixos_test_utils import NixOSTestEnv, validate_config
from .utils.test_summary import TestSummary

@pytest.fixture
def test_env():
    return NixOSTestEnv()

@pytest.fixture
def test_summary():
    return TestSummary()

def test_current_config(test_env, test_summary):
    """Testet die aktuelle Konfiguration"""
    result = validate_config(test_env=test_env)
    
    if result is None:
        test_summary.add_success("current_config")
    else:
        test_summary.add_failure("current_config", result)
    
    assert result is None, "Siehe Zusammenfassung für Details"

def test_basic_config(config_generator, test_env, test_summary):
    """Test einer Basis-Konfiguration"""
    config = {
        'systemType': 'gaming-workstation',
        'bootloader': 'systemd-boot',
        'mainUser': 'fr4iser',  # Existierender User
        'hostName': 'testhost',
        'timeZone': 'Europe/Berlin',
        'locales': ['en_US.UTF-8'],
        'keyboardLayout': 'de',
        'desktop': 'plasma',
        'displayManager': 'sddm',
        'gpu': 'nvidia',
        'audio': 'pipewire'
    }
    
    env_content = config_generator.generate_env(**config)
    result = validate_config(env_content, test_env)
    
    if result is None:
        test_summary.add_success("basic_config")
    else:
        test_summary.add_failure("basic_config", result, env_content)
    
    assert result is None, "Siehe Zusammenfassung für Details"

def test_all_desktops(config_generator, test_env, test_summary):
    """Test aller Desktop-Environments"""
    for desktop in config_generator.base_configs['desktop']:
        env_content = config_generator.generate_env(desktop=desktop)
        error = validate_config(env_content, test_env)
        
        if error is None:
            test_summary.add_success(f"desktop_{desktop}")
        else:
            test_summary.add_failure(f"desktop_{desktop}", error, env_content)
            
        assert error is None, "Siehe Zusammenfassung für Details"

def test_gaming_profile(config_generator, test_env, test_summary):
    """Test des Gaming-Profils"""
    config = {
        'systemType': 'gaming-workstation',
        'desktop': 'plasma',
        'gpu': 'nvidia',
        'overrides': {
            'enableSteam': True,
            'enableFirewall': False
        }
    }
    env_content = config_generator.generate_env(**config)
    result = validate_config(env_content, test_env)
    
    if result is None:
        test_summary.add_success("gaming_profile")
    else:
        test_summary.add_failure("gaming_profile", result, env_content)
        
    assert result is None, "Siehe Zusammenfassung für Details"