import pytest

def test_gaming_profile(test_env, config_generator):
    """Test des Gaming-Profils"""
    config = {
        'systemType': 'gaming',
        'desktop': 'plasma',
        'gpu': 'nvidia',
        'overrides': {
            'enableSteam': True,
            'enableGameMode': True,
            'enableDiscord': True,
            'enableFirewall': False
        }
    }
    
    config_content = config_generator.generate_config(**config)
    test_env.apply_test_config(config_content)
    
    is_valid, error = test_env.validate_config()
    assert is_valid, f"Gaming-Profil ungültig: {error}"

def test_workstation_profile(test_env, config_generator):
    """Test des Workstation-Profils"""
    config = {
        'systemType': 'gaming-workstation',
        'desktop': 'gnome',
        'gpu': 'nvidia',
        'overrides': {
            'enableDocker': True,
            'enableVirtualization': True,
            'enableDevelopmentTools': True
        }
    }
    
    config_content = config_generator.generate_config(**config)
    test_env.apply_test_config(config_content)
    
    is_valid, error = test_env.validate_config()
    assert is_valid, f"Workstation-Profil ungültig: {error}"

def test_headless_profile(test_env, config_generator):
    """Test des Headless-Profils"""
    config = {
        'systemType': 'headless',
        'desktop': None,
        'overrides': {
            'enableSSH': True,
            'enableFirewall': True,
            'enableSystemdBootloader': True
        }
    }
    
    config_content = config_generator.generate_config(**config)
    test_env.apply_test_config(config_content)
    
    is_valid, error = test_env.validate_config()
    assert is_valid, f"Headless-Profil ungültig: {error}"