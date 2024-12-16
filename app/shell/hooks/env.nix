''
  echo "Setting up the NixOsControlCenter development environment..."

  # Projekt-Struktur
  export PROJECT_ROOT=$(pwd)
  export PYTHON_ROOT=$PROJECT_ROOT/app/python
  export NIX_ROOT=$PROJECT_ROOT/app/nix

  # Test-Environment 
  export NIXOS_CONFIG_DIR=$PROJECT_ROOT/nixos
  export PROJECT_TMP_DIR=$PROJECT_ROOT/tmp
  export PYTHON_TEST_TMP_DIR=$PYTHON_ROOT/app/python/tests/tmp
  export PYTHON_TEST_LOG_DIR=$PYTHON_ROOT/app/python/tests/logs

  # Python-spezifische Pfade
  export PYTHONPATH=$PROJECT_ROOT/app/python/src:$PROJECT_ROOT/app/python/tests:$PYTHONPATH
  
  # Nix-spezifische Pfade
  export NIX_PATH=$NIX_ROOT:$NIX_PATH


  # System
  export GCM_CREDENTIAL_STORE=secretservice
  export NIXPKGS_ALLOW_UNFREE=1

  # Debug-Info
  echo "PYTHONPATH includes:"
  echo "  - Application: $PYTHON_ROOT/src"
  echo "  - Tests: $PYTHON_ROOT/tests"
  echo "  - Existing: $PYTHONPATH"

  echo "Project directories set:"
  echo "  - NIXOS_CONFIG_DIR: $NIXOS_CONFIG_DIR"
  echo "  - NIX_ROOT: $NIX_ROOT"
  echo "  - PROJECT_TMP_DIR: $PROJECT_TMP_DIR"
  echo "  - PYTHON_TEST_TMP_DIR: $PYTHON_TEST_TMP_DIR"
  echo "  - PYTHON_TEST_LOG_DIR: $PYTHON_TEST_LOG_DIR"
''