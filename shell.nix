{ pkgs ? import <nixpkgs> {} }:

let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    pygobject3
    flask
    requests
    click
    pytest
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
    makeWrapper
    tree
    nixos-rebuild  # Wichtig für die Tests
  ];

  # Deaktiviere "no new privileges"
  noNewPrivileges = false;

  # Setze notwendige Umgebungsvariablen
  shellHook = ''
    echo "Setting up the NixOsControlCenter development environment..."
    
    export PYTHONPATH=$(pwd)/src:$PYTHONPATH
    echo "PYTHONPATH set to: $PYTHONPATH"

    # Praktische Aliase
    alias py="python3"
    alias pt="pytest tests/"
    alias run="python3 main.py"
    alias rundebug="DEBUG_MODE=1 python3 main.py"
    alias fmt="black ."
    alias lint="flake8 ."
    alias typecheck="mypy ."
    alias doc="pdoc --html --output-dir docs ."
    alias sysmon="python3 -m nixos_control_center.system_monitor"

    echo "Aliases set for development:"
    echo "  py   -> Python interpreter"
    echo "  pt   -> Run tests"
    echo "  run  -> Start main application"
    echo "  rundebug -> Start main application in debug mode"
    echo "  fmt  -> Format code with Black"
    echo "  lint -> Lint code with Flake8"
    echo "  typecheck -> Run Mypy for type checking"
    echo "  doc -> Generate documentation"
    echo "  sysmon -> Start system monitor module"

    # Setze zusätzliche Umgebungsvariablen für sudo
    export NIXPKGS_ALLOW_UNFREE=1
  '';

  # Setze PKG_CONFIG_PATH
  PKG_CONFIG_PATH = "${pkgs.pkg-config}/bin";
}