import pytest


@pytest.mark.profile
def test_gaming_profile(test_environment, config_generator, run_test):
    """Tests gaming profile configuration"""
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
    test_environment.apply_test_config(config_content)
    run_test(config_content)

@pytest.mark.profile
def test_workstation_profile(test_environment, config_generator):
    """Test des Workstation-Profils"""
    config = {
        'systemType': 'gaming-workstation',
        'desktop': 'gnome',
        'session': 'gnome',
        'displayManager': 'gdm',
        'networkManager': {
            'enable': True,
            'dns': 'default',
            'wifi': {
                'powersave': False,
                'scanRandMacAddress': True
            }
        },
        'overrides': {
            'enableDocker': True,
            'enableVirtualization': True,
            'enableDevelopmentTools': True,
            'useAdwaitaTheme': True
        }
    }

    config_content = config_generator.generate_config(**config)
    test_environment.apply_test_config(config_content)

    is_valid, error = test_environment.validate_config()
    assert is_valid, f"Workstation-Profil ungültig: {error}"

@pytest.mark.profile
def test_headless_profile(test_environment, config_generator):
    """Test des Headless-Profils"""
    config = {
        'systemType': 'headless',
        'desktop': '',
        'displayManager': '',
        'session': '',
        'overrides': {
            'enableSSH': True,
            'enableFirewall': True,
            'enableSystemdBootloader': True
        }
    }
    
    config_content = config_generator.generate_config(**config)
    test_environment.apply_test_config(config_content)
    
    is_valid, error = test_environment.validate_config()
    assert is_valid, f"Headless-Profil ungültig: {error}"