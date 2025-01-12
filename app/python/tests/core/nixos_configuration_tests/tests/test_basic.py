import pytest
from pathlib import Path

@pytest.mark.base
def test_basic_config(auto_environment, config_generator, run_test):
    """Tests a basic configuration"""
    test_name = "basic_config"
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
    run_test(config_content, test_name)

@pytest.mark.base
def test_minimal_config(auto_environment, config_generator, run_test):
    """Tests a minimal configuration"""
    test_name = "minimal_config"
    config = {
        'systemType': 'headless',
        'bootloader': 'systemd-boot',
        'mainUser': 'testuser',
        'desktop': '',
        'displayManager': None
    }
    
    config_content = config_generator.generate_config(**config)
    run_test(config_content, test_name)