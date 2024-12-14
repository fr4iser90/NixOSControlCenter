{ pkgs ? import <nixpkgs> {} }:

let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    pygobject3
    flask
    requests
    click
    pytest
    pytest-sugar
    pytest-instafail
    rich
    flake8
    black
    mypy
    pdoc
    psutil
    tkinter
  ]);
in
pkgs.mkShell {
  name = "NixOsControlCenterEnv";

  packages = with pkgs; [
    pythonEnv
    gtk4
    gobject-introspection
    dbus
    pkg-config
    glib
    git
    git-credential-manager
    makeWrapper
    tree
    nixos-rebuild  # Wichtig für die Tests
  ];

  # Deaktiviere "no new privileges"
  noNewPrivileges = false;

  # Setze notwendige Umgebungsvariablen
  shellHook = ''
    echo "Setting up the NixOsControlCenter development environment..."

    # Projekt-Struktur
    export PROJECT_ROOT=$(pwd)
    export PYTHON_ROOT=$PROJECT_ROOT/python
    export NIX_ROOT=$PROJECT_ROOT/nix
    export SHARED_ROOT=$PROJECT_ROOT/shared

    # Test-Environment 
    export PYTHON_NIXOS_CONFIG_DIR=$PYTHON_ROOT/src/nixos
    # Temporäre Verzeichnisse
    export PROJECT_TMP_DIR=$PROJECT_ROOT/tmp
    export PYTHON_TEST_TMP_DIR=$PYTHON_ROOT/tests/tmp
    export PYTHON_TEST_LOG_DIR=$PYTHON_ROOT/tests/log

    # Python-spezifische Pfade
    export PYTHONPATH=$PYTHON_ROOT/src:$PYTHON_ROOT/tests:$PYTHONPATH
    
    # Nix-spezifische Pfade
    export NIX_PATH=$NIX_ROOT:$NIX_PATH

    # Shared Resources
    export ASSETS_DIR=$SHARED_ROOT/assets
    export CONSTANTS_DIR=$SHARED_ROOT/constants

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

    # Aktualisierte Navigations-Aliase
    alias cdp="cd $PROJECT_ROOT"
    alias cdpy="cd $PYTHON_ROOT"
    alias cdnix="cd $NIX_ROOT"
    alias cdshared="cd $SHARED_ROOT"
    alias cdsrc="cd $PYTHON_ROOT/src"
    alias cdtest="cd $PYTHON_ROOT/tests"
    
    # Python Alias
    alias py="python3"
    
    # Aktualisierte Run-Aliase
    alias run="python3 $PYTHON_ROOT/main.py"
    alias rundebug="DEBUG_MODE=1 python3 $PYTHON_ROOT/main.py"
    
    # Test-Funktionen für Random Tests
    function ptr() {
        (cd $PYTHON_ROOT && pytest tests/core/nixos_configuration_tests/tests/test_random.py -m random --random-tests=$1 --test-strategy=full && cd -)
    }

    function ptrv() {
        (cd $PYTHON_ROOT && pytest tests/core/nixos_configuration_tests/tests/test_random.py -m random --random-tests=$1 --test-strategy=validate-only && cd -)
    }

    # Normale Test-Aliase
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

    # Entwicklungs-Tools-Aliase anpassen
    alias fmt="cd $PYTHON_ROOT && black ."
    alias lint="cd $PYTHON_ROOT && flake8 ."
    alias typecheck="cd $PYTHON_ROOT && mypy ."
    alias doc="cd $PYTHON_ROOT && pdoc --html --output-dir ../docs ."

    # Git Credential Manager Konfiguration
    git config --global credential.helper manager
    export GCM_CREDENTIAL_STORE=secretservice
    
    # System Monitor Alias
    alias sysmon="python3 -m nixos_control_center.system_monitor"
    
    # Debug-Info ausgeben
    echo "Aliases set for development:"
    echo "  py   -> Python interpreter"
    echo "  run  -> Start main application"
    echo "  rundebug -> Start main application in debug mode"
    echo "  fmt  -> Format code with Black"
    echo "  lint -> Lint code with Flake8"
    echo "  typecheck -> Run Mypy for type checking"
    echo "  doc -> Generate documentation"
    echo "  sysmon -> Start system monitor module"
    
    echo "Test aliases set:"
    echo "  pt       -> Run all tests"
    echo "  ptf      -> Run tests with full strategy(Validate + Build)"
    echo "  ptv      -> Run tests explizit validate-only"
    echo "  ptvv     -> Run tests very verbose"
    echo "  pt-basic -> Run basic tests"
    echo "  pt-profiles -> Run profile tests"
    echo "  pt-hardware -> Run hardware tests"
    echo "  pt-failed   -> Run failed tests"
    echo "  pt-first    -> Run failed tests first"
    echo "  pt-log      -> Run tests with logs"
    echo "  pt-random   -> Run marked random tests"
    echo "  ptr N     -> Run N random tests with full strategy (example: ptr 50)"
    echo "  ptrv N    -> Run N random tests validate-only (example: ptrv 10)"

    # Setze zusätzliche Umgebungsvariablen für sudo
    export NIXPKGS_ALLOW_UNFREE=1
  '';

  # Setze PKG_CONFIG_PATH
  PKG_CONFIG_PATH = "${pkgs.pkg-config}/bin";
}