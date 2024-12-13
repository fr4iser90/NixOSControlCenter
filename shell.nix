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

    # Setze Projekt-Verzeichnisse
    export PROJECT_ROOT=$(pwd)
    export NIXOS_CONFIG_DIR=$PROJECT_ROOT/src/nixos
    export BACKEND_DIR=$PROJECT_ROOT/src/backend
    export FRONTEND_DIR=$PROJECT_ROOT/src/frontend
    export CORE_DIR=$PROJECT_ROOT/src/core
 
    export PYTHONPATH=$(pwd)/src:$(pwd)/tests:$PYTHONPATH
    echo "PYTHONPATH includes:"
    echo "  - Application: $(pwd)/src"
    echo "  - Tests: $(pwd)/tests"
    echo "  - Existing: $PYTHONPATH"


    echo "Project directories set:"
    echo "  - NIXOS_CONFIG_DIR: $NIXOS_CONFIG_DIR"
    echo "  - BACKEND_DIR: $BACKEND_DIR"
    echo "  - FRONTEND_DIR: $FRONTEND_DIR"
    echo "  - CORE_DIR: $CORE_DIR"

    # Praktische Navigations-Aliase
    alias cdp="cd $PROJECT_ROOT"
    alias cdsrc="cd $PROJECT_ROOT/src"
    alias cdnix="cd $NIXOS_CONFIG_DIR"
    alias cdback="cd $BACKEND_DIR"
    alias cdfront="cd $FRONTEND_DIR"
    alias cdcore="cd $CORE_DIR"
    alias cdtest="cd $PROJECT_ROOT/tests"

    # Git Credential Manager Konfiguration
    git config --global credential.helper manager
    export GCM_CREDENTIAL_STORE=secretservice
    
    # Praktische Aliase
    alias py="python3"
    alias run="python3 main.py"
    alias rundebug="DEBUG_MODE=1 python3 main.py"
    alias fmt="black ."
    alias lint="flake8 ."
    alias typecheck="mypy ."
    alias doc="pdoc --html --output-dir docs ."
    alias sysmon="python3 -m nixos_control_center.system_monitor"
    
    # Test-Aliase
    alias pt='pytest'
    alias ptf='pytest --test-strategy=full'  # Full strategy
    alias ptv='pytest --test-strategy=validate-only'  # Validate only
    alias ptvv="pytest -vv"
    alias pt-basic="pytest tests/core/config/test_basic.py"
    alias pt-profiles="pytest tests/core/config/test_profiles.py"
    alias pt-hardware="pytest tests/core/config/test_hardware.py"
    alias pt-failed="pytest --lf"
    alias pt-first="pytest --ff"
    alias pt-log="pytest -s"

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
    echo "  ptc      -> Run core tests"
    echo "  ptf      -> Run tests with full strategy(Validate + Build)"
    echo "  ptv      -> Run tests explizit validate-only"
    echo "  ptvv     -> Run tests very verbose"
    echo "  pt-basic -> Run basic tests"
    echo "  pt-profiles -> Run profile tests"
    echo "  pt-hw    -> Run hardware tests"
    echo "  pt-hardware -> Run hardware-marked tests"
    echo "  pt-profile  -> Run profile-marked tests"
    echo "  pt-failed   -> Run failed tests"
    echo "  pt-first    -> Run failed tests first"
    echo "  pt-log      -> Run tests with logs"

    # Setze zusätzliche Umgebungsvariablen für sudo
    export NIXPKGS_ALLOW_UNFREE=1
  '';

  # Setze PKG_CONFIG_PATH
  PKG_CONFIG_PATH = "${pkgs.pkg-config}/bin";
}