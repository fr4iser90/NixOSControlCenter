import pytest

def test_nvidia_config(test_env, config_generator):
    """Test der NVIDIA-Konfiguration"""
    config = {
        'gpu': 'nvidia',
        'overrides': {
            'enableNvidiaDrivers': True,
            'enableCuda': True,
            'enableVulkan': True
        }
    }
    
    config_content = config_generator.generate_config(**config)
    test_env.apply_test_config(config_content)
    
    is_valid, error = test_env.validate_config()
    assert is_valid, f"NVIDIA-Konfiguration ungültig: {error}"

def test_amd_config(test_env, config_generator):
    """Test der AMD-Konfiguration"""
    config = {
        'gpu': 'amdgpu',
        'overrides': {
            'enableAmdgpu': True,
            'enableVulkan': True,
            'enableOpenCL': True
        }
    }
    
    config_content = config_generator.generate_config(**config)
    test_env.apply_test_config(config_content)
    
    is_valid, error = test_env.validate_config()
    assert is_valid, f"AMD-Konfiguration ungültig: {error}"

def test_audio_config(test_env, config_generator):
    """Test der Audio-Konfiguration"""
    configs = [
        {
            'audio': 'pipewire',
            'overrides': {
                'enablePipewire': True,
                'enableBluetooth': True
            }
        },
        {
            'audio': 'pulseaudio',
            'overrides': {
                'enablePulseaudio': True
            }
        }
    ]
    
    for config in configs:
        config_content = config_generator.generate_config(**config)
        test_env.apply_test_config(config_content)
        
        is_valid, error = test_env.validate_config()
        assert is_valid, f"{config['audio']}-Konfiguration ungültig: {error}"

def test_peripheral_config(test_env, config_generator):
    """Test der Peripherie-Konfiguration"""
    config = {
        'overrides': {
            'enableBluetooth': True,
            'enablePrinting': True,
            'enableScanning': True,
            'enableWebcam': True
        }
    }
    
    config_content = config_generator.generate_config(**config)
    test_env.apply_test_config(config_content)
    
    is_valid, error = test_env.validate_config()
    assert is_valid, f"Peripherie-Konfiguration ungültig: {error}"