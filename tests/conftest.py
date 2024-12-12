import pytest
from pathlib import Path
from core.utils.config_generator import ConfigGenerator
from core.utils.test_env import TestEnvironment
from core.utils.test_validator import ConfigValidator

# Basis-Fixtures
@pytest.fixture(scope="session")
def project_root():
    """Projekt-Wurzelverzeichnis"""
    return Path(__file__).parent.parent

@pytest.fixture(scope="session")
def test_root(project_root):
    """Test-Wurzelverzeichnis"""
    return project_root / "tests"

@pytest.fixture(scope="session")
def temp_dir(test_root):
    """Temporäres Testverzeichnis"""
    tmp = test_root / "tmp"
    tmp.mkdir(exist_ok=True)
    return tmp

# Core-Fixtures
@pytest.fixture(scope="session")
def config_generator():
    """Zentrale Konfigurations-Generator Instanz"""
    return ConfigGenerator()

@pytest.fixture(scope="session")
def test_env(temp_dir):
    """Basis Test-Umgebung"""
    return TestEnvironment(temp_dir)

@pytest.fixture
def test_environment(test_env):
    """Fixture für Setup und Cleanup der Testumgebung"""
    test_env.setup_test_env()
    yield test_env
    test_env.cleanup()

@pytest.fixture(scope="session")
def config_validator():
    """Konfigurations-Validator"""
    return ConfigValidator()