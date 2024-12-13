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

console = Console(force_terminal=True, file=sys.stderr)

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

def generate_random_test_configs(config_generator):
    """Generiert die Test-Konfigurationen vorab"""
    test_configs = config_generator.generate_test_variants(
        components=['systemType', 'desktop', 'displayManager', 'gpu', 'audio', 'bootloader'],
        max_combinations=20
    )
    
    configs = []
    for idx, base_config in enumerate(test_configs, 1):
        config = {
            **base_config,
            'mainUser': 'testuser',
            'hostName': f'test-{random.randint(1000, 9999)}',
            'timeZone': random.choice(config_generator.available_options['timeZones']),
            'locales': [random.choice(config_generator.available_options['locales'])],
            'keyboardLayout': random.choice(config_generator.available_options['keyboardLayouts']),
            'overrides': _generate_random_overrides()
        }
        configs.append((f"random_config_{idx}", config))
    return configs

@pytest.mark.random
@pytest.mark.parametrize("test_idx", range(20))
def test_random_configuration(auto_environment, config_generator, run_test, test_idx):
    """Tests a random configuration"""
    
    # Generate base config with valid combinations
    base_config = {
        'systemType': random.choice(['gaming-workstation', 'workstation', 'headless']),
        'bootloader': 'systemd-boot',  # Start with safe defaults
        'mainUser': 'testuser',
        'hostName': 'testhost',  # Must match flake.nix configuration
    }
    
    # Add desktop environment if not headless
    if base_config['systemType'] != 'headless':
        base_config.update({
            'desktop': random.choice(['plasma', 'gnome', 'xfce']),
            'displayManager': 'sddm',  # Will be adjusted based on desktop
            'gpu': random.choice(['nvidia', 'amdgpu', 'intel']),
            'audio': random.choice(['pipewire', 'pulseaudio'])
        })
        
        # Adjust displayManager based on desktop
        if base_config['desktop'] == 'gnome':
            base_config['displayManager'] = 'gdm'
    else:
        # Headless configuration
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
    
    test_name = f"random_config_{test_idx}"
    config_content = config_generator.generate_config(**config)
    
    # Execute test with proper flake configuration
    sys.stdout.flush()
    sys.stderr.flush()
    run_test(config_content, test_name)