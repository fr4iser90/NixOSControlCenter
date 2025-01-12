"""
Test execution related fixtures.
Handles test strategy, execution, and command line options.
"""

import pytest
import time

@pytest.fixture(scope="session")
def test_strategy(request):
    """
    Determines test strategy: validate-only or validate-and-build.
    Controlled via --test-strategy command line option.
    """
    return request.config.getoption("--test-strategy", default="validate-only")

@pytest.fixture
def run_test(auto_environment, test_strategy):
    def _run_test(config_content, test_name):
        try:
            # Neues Environment für jeden Test
            auto_environment.apply_test_config(config_content, test_name)

            time.sleep(0.5)
            # Validierung
            is_valid, error = auto_environment.validate_config()
            if not is_valid:
                pytest.fail(f"Validation failed for {test_name}: {error}")
            
            # Build wenn strategy=full
            if test_strategy == "full":
                success, error = auto_environment.build_config()
                if not success:
                    pytest.fail(f"Build failed for {test_name}: {error}")
                
            return True, None
            
        except Exception as e:
            pytest.fail(f"Test failed: {str(e)}")
            return False, str(e)
    
    return _run_test

@pytest.fixture
def random_config(config_generator):
    """Generates a single random configuration"""
    def _generate():
        # Generiere eine einzelne zufällige Basis-Konfiguration
        base_config = config_generator.generate_test_variants(
            components=['systemType', 'desktop', 'displayManager', 'gpu', 'audio', 'bootloader'],
            max_combinations=1
        )[0]
        
        # Erweitere sie mit zufälligen Werten
        config = {
            **base_config,
            'mainUser': 'testuser',
            'hostName': f'test-{random.randint(1000, 9999)}',
            'timeZone': random.choice(config_generator.available_options['timeZones']),
            'locales': [random.choice(config_generator.available_options['locales'])],
            'keyboardLayout': random.choice(config_generator.available_options['keyboardLayouts']),
            'overrides': _generate_random_overrides()
        }
        return config
    return _generate