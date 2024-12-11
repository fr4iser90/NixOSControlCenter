import pytest
from pathlib import Path

def test_basic_config(test_env, config_generator):
    """Test einer Basis-Konfiguration"""
    config = {
        'systemType': 'gaming-workstation',
        'bootloader': 'systemd-boot',
        'mainUser': 'testuser',
        'hostName': 'testhost',
        'timeZone': 'Europe/Berlin',
        'locales': ['en_US.UTF-8'],
        'keyboardLayout': 'de',
        'desktop': 'plasma',
        'displayManager': 'sddm',
        'gpu': 'nvidia',
        'audio': 'pipewire'
    }
    
    # Generiere und wende Konfiguration an
    config_content = config_generator.generate_config(**config)
    test_env.apply_test_config(config_content)
    
    # Validiere Konfiguration
    is_valid, error = test_env.validate_config()
    assert is_valid, f"Konfiguration ungültig: {error}"
    
    # Build-Test
    success, error = test_env.build_config()
    assert success, f"Build fehlgeschlagen: {error}"

def test_minimal_config(test_env, config_generator):
    """Test einer minimalen Konfiguration"""
    config = {
        'systemType': 'headless',
        'bootloader': 'systemd-boot',
        'mainUser': 'testuser',
        'desktop': None
    }
    
    config_content = config_generator.generate_config(**config)
    test_env.apply_test_config(config_content)
    
    is_valid, error = test_env.validate_config()
    assert is_valid, f"Minimale Konfiguration ungültig: {error}"