"""
Random configuration test generator.
Tests random combinations of NixOS configurations.
"""
import pytest
import random
from rich.console import Console
from typing import Dict
import sys
from ..handlers.nixos_config_generator import NixOSEnvGenerator
from ..handlers.nixos_error_handler import NixOSErrorHandler

console = Console(force_terminal=True, file=sys.stderr)

def pytest_generate_tests(metafunc):
    """Dynamically generate test cases based on --random-tests option"""
    if "test_idx" in metafunc.fixturenames:
        num_tests = metafunc.config.getoption("--random-tests")
        metafunc.parametrize("test_idx", range(num_tests))

def _generate_random_overrides() -> Dict[str, bool]:
    """Generates random override settings."""
    possible_overrides = [
        'enableSSH',
        'enableSteam',
        'enableGameMode',
        'enableDiscord',
        'enableDocker',
        'enableVirtualization',
        'enableDevelopmentTools',
        'enableSystemdBootloader',
        'enableFirewall',
        'enableBluetooth',
        'enablePrinting',
        'enableWebcam'
    ]
    return {
        override: random.choice([True, False])
        for override in random.sample(possible_overrides, random.randint(3, 6))
    }

@pytest.mark.random
def test_random_configuration(auto_environment, config_generator, run_test, test_idx):
    """Tests a random configuration"""
    error_handler = NixOSErrorHandler()
    test_name = f"random_config_{test_idx}"
    
    try:
        # Generate base config
        base_config = {
            'systemType': random.choice(['gaming-workstation', 'workstation', 'headless']),
            'bootloader': 'systemd-boot',
            'mainUser': 'testuser',
            'hostName': 'testhost',
        }
        
        # Add desktop environment if not headless
        if base_config['systemType'] != 'headless':
            base_config.update({
                'desktop': random.choice(['plasma', 'gnome', 'xfce']),
                'displayManager': 'sddm',
                'gpu': random.choice(['nvidia', 'amdgpu', 'intel']),
                'audio': random.choice(['pipewire', 'pulseaudio'])
            })
            
            if base_config['desktop'] == 'gnome':
                base_config['displayManager'] = 'gdm'
        else:
            base_config.update({
                'desktop': None,
                'displayManager': None,
                'gpu': None,
                'audio': 'alsa'
            })
        
        # Add common configurations
        config = {
            **base_config,
            'timeZone': random.choice(config_generator.available_options['timeZones']),
            'locales': [random.choice(config_generator.available_options['locales'])],
            'keyboardLayout': random.choice(config_generator.available_options['keyboardLayouts']),
            'overrides': _generate_random_overrides()
        }
        
        # Generate NixOS configuration
        generated_nix_config = config_generator.generate_config(**config)
        
        
        # Run test with SAME handler
        success, error = run_test(generated_nix_config, test_name)
        
        if not success:
            error_handler.add_error(error)
            summary = error_handler.get_summary(test_name)
            console.print(summary)
            pytest.fail(f"Build failed for {test_name}: {error}")
            
    except Exception as e:
        error_handler.add_error(str(e))
        summary = error_handler.get_summary(test_name)
        console.print(summary)
        raise