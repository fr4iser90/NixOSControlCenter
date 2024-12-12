import pytest
import time
import os
from pathlib import Path
from core.nixos_configuration_tests.managers.config_manager import ConfigManager
from core.nixos_configuration_tests.handlers.environment_handler import EnvironmentHandler
from core.nixos_configuration_tests.handlers.nixos_config_generator import ConfigGenerator
from core.nixos_configuration_tests.handlers.nixos_config_validator import ConfigValidator
from core.nixos_configuration_tests.handlers.nixos_config_builder import NixConfigBuilder
from core.nixos_configuration_tests.handlers.summary_handler import NixConfigErrorHandler, SummaryHandler

from utils.session_manager import SessionManager
import sys
from typing import Optional


# Globale Variablen
_start_time = None
_total_tests = 0
_current_test = 0
session = SessionManager()

# Fixtures
@pytest.fixture(scope="session")
def project_root():
    """Returns the project root directory"""
    return Path(__file__).parent.parent

@pytest.fixture(scope="session")
def test_root(project_root):
    return project_root / "tests"

@pytest.fixture(scope="session")
def temp_dir(test_root):
    tmp = test_root / "tmp"
    tmp.mkdir(exist_ok=True)
    return tmp

@pytest.fixture(scope="session")
def config_generator():
    return ConfigGenerator()

@pytest.fixture(scope="session")
def test_env(temp_dir):
    """Setup the test environment with correct NIXOS_CONFIG_DIR"""
    nixos_config_dir = os.environ.get('NIXOS_CONFIG_DIR')
    if not nixos_config_dir:
        raise RuntimeError("NIXOS_CONFIG_DIR environment variable is not set!")
        
    nixos_config_path = Path(nixos_config_dir)
    if not nixos_config_path.exists():
        raise RuntimeError(f"NIXOS_CONFIG_DIR path does not exist: {nixos_config_dir}")
    
    # Verify required files exist
    required_files = ['flake.nix', 'flake.lock', 'hardware-configuration.nix', 'env.nix']
    missing_files = [f for f in required_files if not (nixos_config_path / f).exists()]
    if missing_files:
        raise RuntimeError(f"Missing required files in {nixos_config_dir}: {missing_files}")
        
    # Verify modules directory exists
    modules_path = nixos_config_path / "modules"
    if not modules_path.exists() or not modules_path.is_dir():
        raise RuntimeError(f"Modules directory not found at {modules_path}")
        
    print(f"\nNixOS Config Directory Setup:")
    print(f"  Path: {nixos_config_path}")
    print(f"  Files found: {list(nixos_config_path.glob('*'))}")
    print(f"  Modules found: {list(modules_path.glob('*'))}")
    
    return EnvironmentHandler(temp_dir)

@pytest.fixture
def test_environment(test_env):
    """Provides a fresh test environment for each test"""
    try:
        env = test_env.setup_test_env()
        print(f"\nTest environment created at: {env}")
        print(f"Files present: {list(env.glob('*'))}")
        yield test_env
    finally:
        test_env.cleanup()

@pytest.fixture(scope="session")
def config_validator():
    return ConfigValidator()

def pytest_configure(config):
    """Basis-Konfiguration"""
    config.option.verbose = 0
    config.option.showlocals = False
    config.option.showcapture = "no"
    
    # Deaktiviere pytest's eigene Zusammenfassungen
    config.option.reportchars = ""


def pytest_terminal_summary(terminalreporter, exitstatus, config):
    """Unterdrückt die pytest-Zusammenfassung"""
    # Verhindere die Standard-Zusammenfassung
    terminalreporter.stats = {}
    terminalreporter._session.testsfailed = 0
    terminalreporter._session.testsnotrun = 0

@pytest.fixture(scope="session")
def test_strategy(request):
    """Determines test strategy: validate-only or validate-and-build"""
    return request.config.getoption("--test-strategy", default="validate-only")

@pytest.fixture
def run_test(test_environment, test_strategy):
    """Handles test execution based on strategy"""
    def _run_test(config_content):
        # Always validate
        is_valid, error = test_environment.validate_config()
        assert is_valid, f"Configuration validation failed: {error}"
        
        # Build only if strategy is 'full'
        if test_strategy == "full":
            success, error = test_environment.build_config()
            assert success, f"Configuration build failed: {error}"
    
    return _run_test

def pytest_addoption(parser):
    # Vorhandene Option
    parser.addoption("--show-progress", action="store_true", 
                    help="Show progress bar during tests")
    
    # Neue Option für Teststrategie
    parser.addoption(
        "--test-strategy",
        choices=["validate-only", "full"],
        default="validate-only",
        help="Test strategy: validate-only or full (validate + build)"
    )


def pytest_sessionstart(session):
    """Session Start Handler"""
    global _start_time
    _start_time = time.time()
    NixConfigErrorHandler.clear()
    SummaryHandler.clear()
    print("\n🚀 Starting NixOS Configuration Tests\n")


@pytest.fixture(autouse=True)
def setup_test_name(request, test_environment):
    """Setzt automatisch den Testnamen für jeden Test"""
    test_name = request.node.name
    test_environment.config_manager.set_current_test(test_name)
    yield

def update_progress(test_name: Optional[str] = None):
    """Aktualisiert die Fortschrittsanzeige"""
    global _current_test, _total_tests
    if test_name:
        _current_test += 1
        progress = f"[{_current_test}/{_total_tests}]"
        sys.stdout.write(f"\rRunning: {test_name:<50} {progress}")
        sys.stdout.flush()

def pytest_collection_modifyitems(session, config, items):
    """Wird aufgerufen nachdem alle Tests gesammelt wurden"""
    global _total_tests
    _total_tests = len(items)
    print(f"\nCollected {_total_tests} tests\n")

@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_protocol(item, nextitem):
    """Test-Ausführungs-Hook"""
    update_progress(item.name)
    yield
    sys.stdout.write("\n")
    sys.stdout.flush()

@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    """Test Result Handler"""
    outcome = yield
    result = outcome.get_result()

    if result.when == "call":
        test_name = item.name
        passed = result.outcome == "passed"
        
        # Sammle Testergebnis
        SummaryHandler.add_result(test_name, passed)
        
        # Bei Fehler, sammle Fehlermeldung
        if not passed and hasattr(result, "longrepr"):
            error_msg = str(result.longrepr)
            NixConfigErrorHandler.format_error(error_msg, test_name)


def pytest_sessionfinish(session):
    """Session Finish Handler - Druckt finale Zusammenfassungen"""
    global _start_time
    duration = time.time() - _start_time
    SummaryHandler.set_execution_time(duration)
    
    # Drucke Test Zusammenfassung
    print("\n" + SummaryHandler.get_summary())
    
    # Wenn Fehler aufgetreten sind, drucke Fehler-Zusammenfassung
    if NixConfigErrorHandler._collected_errors:
        print("\n" + NixConfigErrorHandler.get_summary())

    # Aufräumen
    SummaryHandler.clear()
    NixConfigErrorHandler.clear()