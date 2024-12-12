import pytest
from core.nixos_configuration_tests.handlers.environment_handler import EnvironmentHandler
from core.nixos_configuration_tests.handlers.nixos_config_generator import ConfigGenerator

def test_nvidia_config(test_environment, config_generator, run_test):
    """Tests NVIDIA GPU configuration"""
    config = {
        'gpu': 'nvidia',
        'overrides': {
            'enableNvidiaDrivers': True,
            'enableCuda': True,
            'enableVulkan': True
        }
    }
    
    config_content = config_generator.generate_config(**config)
    test_environment.apply_test_config(config_content)
    run_test(config_content)

def test_amd_config(test_environment, config_generator, run_test):
    """Tests AMD GPU configuration"""
    config = {
        'gpu': 'amdgpu',
        'overrides': {
            'enableAmdgpu': True,
            'enableVulkan': True,
            'enableOpenCL': True
        }
    }
    
    config_content = config_generator.generate_config(**config)
    test_environment.apply_test_config(config_content)
    run_test(config_content)

def test_pipewire_config(test_environment, config_generator):
    """Test Pipewire audio configuration"""
    config = {
        'systemType': 'gaming-workstation',
        'desktop': 'plasma',
        'audio': 'pipewire',
        'mainUser': 'testuser',
        'hostName': 'testhost',
        'timeZone': 'Europe/Berlin',
        'locales': ['en_US.UTF-8'],
        'keyboardLayout': 'de',
        'bootloader': 'systemd-boot',
        'displayManager': 'sddm',
        'session': 'plasmawayland',
        'overrides': {
            'enablePipewire': True,
            'enableSound': True,
            'enableBluetooth': True
        }
    }
    
    config_content = config_generator.generate_config(**config)
    test_environment.apply_test_config(config_content)
    
    is_valid, error = test_environment.validate_config()
    assert is_valid, f"Invalid Pipewire configuration: {error}"

def test_pulseaudio_config(test_environment, config_generator):
    """Test PulseAudio configuration"""
    config = {
        'systemType': 'gaming-workstation',
        'desktop': 'plasma',
        'audio': 'pulseaudio',
        'mainUser': 'testuser',
        'hostName': 'testhost',
        'timeZone': 'Europe/Berlin',
        'locales': ['en_US.UTF-8'],
        'keyboardLayout': 'de',
        'bootloader': 'systemd-boot',
        'displayManager': 'sddm',
        'session': 'plasmawayland',
        'overrides': {  
            'enablePulseaudio': True,
            'enableSound': True,
            'enableBluetooth': True
        }
    }
    
    config_content = config_generator.generate_config(**config)
    test_environment.apply_test_config(config_content)
    
    is_valid, error = test_environment.validate_config()
    assert is_valid, f"Invalid PulseAudio configuration: {error}"

def test_alsa_config(test_environment, config_generator):
    """Test ALSA configuration"""
    config = {
        'systemType': 'headless',
        'desktop': None,
        'audio': 'alsa',
        'mainUser': 'testuser',
        'hostName': 'testhost',
        'timeZone': 'Europe/Berlin',
        'locales': ['en_US.UTF-8'],
        'keyboardLayout': 'de',
        'bootloader': 'systemd-boot',
        'displayManager': None,
        'session': None,
        'overrides': {
            'enableAlsa': True,
            'enableSound': True
        }
    }
    
    config_content = config_generator.generate_config(**config)
    test_environment.apply_test_config(config_content)
    
    is_valid, error = test_environment.validate_config()
    assert is_valid, f"Invalid ALSA configuration: {error}"

# Optional: Platzhalter für zukünftige Audio-Tests
@pytest.mark.skip(reason="Not implemented yet")
def test_jack_config(test_environment, config_generator):
    """Test JACK audio configuration (placeholder)"""
    pass

def test_peripheral_config(test_environment, config_generator):
    """Tests peripheral device configurations"""
    config = {
        'overrides': {
            'enableBluetooth': True,
            'enablePrinting': True,
            'enableScanning': True,
            'enableWebcam': True
        }
    }
    
    config_content = config_generator.generate_config(**config)
    test_environment.apply_test_config(config_content)
    
    is_valid, error = test_environment.validate_config()
    assert is_valid, f"Invalid peripheral configuration: {error}"