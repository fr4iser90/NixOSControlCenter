import pytest

@pytest.mark.profile
def test_gaming_profile(auto_environment, config_generator, run_test):
    """Tests gaming profile configuration"""
    test_name = "gaming_profile"
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
    run_test(config_content, test_name)

@pytest.mark.profile
def test_workstation_profile(auto_environment, config_generator, run_test):  # run_test hinzugefügt
    """Test des Workstation-Profils"""
    test_name = "workstation_profile"
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
    run_test(config_content, test_name)

@pytest.mark.profile
def test_headless_profile(auto_environment, config_generator, run_test):  # run_test hinzugefügt
    """Test des Headless-Profils"""
    test_name = "headless_profile"
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
    run_test(config_content, test_name)