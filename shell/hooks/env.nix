''
  echo "Setting up the NixOsControlCenter development environment..."

  # Projekt-Struktur
  export PROJECT_ROOT=$(pwd)
  export PYTHON_ROOT=$PROJECT_ROOT/python
  export NIX_ROOT=$PROJECT_ROOT/nix
  export SHARED_ROOT=$PROJECT_ROOT/shared

  # Test-Environment 
  export PYTHON_NIXOS_CONFIG_DIR=$PYTHON_ROOT/src/nixos
  export PROJECT_TMP_DIR=$PROJECT_ROOT/tmp
  export PYTHON_TEST_TMP_DIR=$PYTHON_ROOT/tests/tmp
  export PYTHON_TEST_LOG_DIR=$PYTHON_ROOT/tests/logs

  # Python-spezifische Pfade
  export PYTHONPATH=$PYTHON_ROOT/src:$PYTHON_ROOT/tests:$PYTHONPATH
  
  # Nix-spezifische Pfade
  export NIX_PATH=$NIX_ROOT:$NIX_PATH

  # Shared Resources
  export ASSETS_DIR=$SHARED_ROOT/assets
  export CONSTANTS_DIR=$SHARED_ROOT/constants

  # System
  export GCM_CREDENTIAL_STORE=secretservice
  export NIXPKGS_ALLOW_UNFREE=1

  # Debug-Info
  echo "PYTHONPATH includes:"
  echo "  - Application: $PYTHON_ROOT/src"
  echo "  - Tests: $PYTHON_ROOT/tests"
  echo "  - Existing: $PYTHONPATH"

  echo "Project directories set:"
  echo "  - PYTHON_NIXOS_CONFIG_DIR: $PYTHON_NIXOS_CONFIG_DIR"
  echo "  - NIX_ROOT: $NIX_ROOT"
  echo "  - PYTHON_ROOT: $PYTHON_ROOT"
  echo "  - SHARED_ROOT: $SHARED_ROOT"
  echo "  - PROJECT_TMP_DIR: $PROJECT_TMP_DIR"
  echo "  - PYTHON_TEST_TMP_DIR: $PYTHON_TEST_TMP_DIR"
  echo "  - PYTHON_TEST_LOG_DIR: $PYTHON_TEST_LOG_DIR"
''