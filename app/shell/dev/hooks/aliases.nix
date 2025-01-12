# app/shell/dev/hooks/aliases.nix
{ pkgs }:

''
  # Navigation
  alias cdp="cd $PROJECT_ROOT"
  alias cdpy="cd $PYTHON_ROOT"
  alias cdnix="cd $NIX_ROOT"
  alias cdsrc="cd $PYTHON_ROOT/src"
  alias cdtest="cd $PYTHON_ROOT/tests"
  
  # Python und Run
  alias py="python3"
  alias run="python3 $PYTHON_ROOT/main.py"
  alias rundebug="DEBUG_MODE=1 python3 $PYTHON_ROOT/main.py"
  
  # Test-Funktionen
  function ptr() {
    (cd $PYTHON_ROOT && pytest tests/core/nixos_configuration_tests/tests/test_random.py -m random --random-tests=$1 --test-strategy=full && cd -)
  }

  function ptrv() {
    (cd $PYTHON_ROOT && pytest tests/core/nixos_configuration_tests/tests/test_random.py -m random --random-tests=$1 --test-strategy=validate-only && cd -)
  }

  # Test-Aliase
  alias pt='(cd $PYTHON_ROOT && pytest && cd -)'
  alias ptf='(cd $PYTHON_ROOT && pytest --test-strategy=full && cd -)'
  alias ptv='(cd $PYTHON_ROOT && pytest --test-strategy=validate-only && cd -)'
  alias ptvv="(cd $PYTHON_ROOT && pytest -vv && cd -)"
  alias pt-basic="(cd $PYTHON_ROOT && pytest tests/core/nixos_configuration_tests/tests/test_basic.py && cd -)"
  alias pt-profiles="(cd $PYTHON_ROOT && pytest tests/core/nixos_configuration_tests/tests/test_profiles.py && cd -)"
  alias pt-hardware="(cd $PYTHON_ROOT && pytest tests/core/nixos_configuration_tests/tests/test_hardware.py && cd -)"
  alias pt-failed="(cd $PYTHON_ROOT && pytest --lf && cd -)"
  alias pt-first="(cd $PYTHON_ROOT && pytest --ff && cd -)"
  alias pt-log="(cd $PYTHON_ROOT && pytest -s && cd -)"
  alias pt-random="(cd $PYTHON_ROOT && pytest -m random && cd -)"

  # Entwicklungs-Tools
  alias fmt="cd $PYTHON_ROOT && black ."
  alias lint="cd $PYTHON_ROOT && flake8 ."
  alias typecheck="cd $PYTHON_ROOT && mypy ."
  alias doc="cd $PYTHON_ROOT && pdoc --html --output-dir ../docs ."
  
  # System
  alias sysmon="python3 -m nixos_control_center.system_monitor"

  # Git Konfiguration
  git config --global credential.helper manager
''