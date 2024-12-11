import pytest
from pathlib import Path
from core.utils.config_generator import ConfigGenerator
from core.utils.env_handler import EnvHandler
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
def env_handler(temp_dir):
    """Umgebungs-Handler für Tests"""
    return EnvHandler(temp_dir)

@pytest.fixture(scope="session")
def config_validator():
    """Konfigurations-Validator"""
    return ConfigValidator()

# Cleanup
@pytest.fixture(autouse=True)
def cleanup_temp(temp_dir):
    """Räumt temporäre Testdateien auf"""
    yield
    for item in temp_dir.iterdir():
        if item.is_file():
            item.unlink()