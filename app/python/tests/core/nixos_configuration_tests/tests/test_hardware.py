import pytest

@pytest.mark.hardware
def test_nvidia_config(auto_environment, config_generator, run_test):
    """Tests NVIDIA GPU configuration with all features"""
    config = {
        'gpu': 'nvidia',
        'systemType': 'workstation',  # Typically needed for CUDA
        'overrides': {
            'enableNvidiaDrivers': True,
            'enableCuda': True,
            'enableVulkan': True,
            'enableOpenGL': True,
            'enableComputeCapabilities': True
        }
    }
    
    run_test(config_generator.generate_config(**config), "nvidia_full_features")

@pytest.mark.hardware
def test_amd_config(auto_environment, config_generator, run_test):
    """Tests AMD GPU configuration"""
    test_name = "amd_config"
    config = {
        'gpu': 'amdgpu',
        'overrides': {
            'enableAmdgpu': True,
            'enableVulkan': True,
            'enableOpenCL': True
        }
    }
    
    config_content = config_generator.generate_config(**config)
    run_test(config_content, test_name)

@pytest.mark.hardware
def test_pipewire_config(auto_environment, config_generator, run_test):
    """Test Pipewire audio configuration"""
    test_name = "pipewire_config"
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
    run_test(config_content, test_name)

@pytest.mark.hardware
def test_pulseaudio_config(auto_environment, config_generator, run_test):
    """Test PulseAudio configuration"""
    test_name = "pulseaudio_config"
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
    run_test(config_content, test_name)

@pytest.mark.hardware
def test_alsa_config(auto_environment, config_generator, run_test):
    """Test ALSA configuration"""
    test_name = "alsa_config"
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
    run_test(config_content, test_name)

@pytest.mark.skip(reason="Not implemented yet")
@pytest.mark.hardware
def test_jack_config(auto_environment, config_generator, run_test):
    """Test JACK audio configuration (placeholder)"""
    pass

@pytest.mark.hardware
def test_peripheral_config(auto_environment, config_generator, run_test):
    """Tests peripheral device configurations"""
    test_name = "peripheral_config"
    config = {
        'overrides': {
            'enableBluetooth': True,
            'enablePrinting': True,
            'enableScanning': True,
            'enableWebcam': True
        }
    }
    
    config_content = config_generator.generate_config(**config)
    run_test(config_content, test_name)