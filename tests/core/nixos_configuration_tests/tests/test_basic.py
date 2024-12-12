import pytest
from pathlib import Path

def test_basic_config(test_environment, config_generator, run_test):
    """Tests a basic configuration"""
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
    
    config_content = config_generator.generate_config(**config)
    test_environment.apply_test_config(config_content)
    run_test(config_content)

def test_minimal_config(test_environment, config_generator, run_test):
    """Tests a minimal configuration"""
    config = {
        'systemType': 'headless',
        'bootloader': 'systemd-boot',
        'mainUser': 'testuser',
        'desktop': '',
        'displayManager': None
    }
    
    config_content = config_generator.generate_config(**config)
    test_environment.apply_test_config(config_content)
    run_test(config_content)