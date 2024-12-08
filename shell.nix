{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "NixOsControlCenterEnv";

  # Build Inputs: Alles, was du für Entwicklung und Tests brauchst
  buildInputs = [
    pkgs.python3
    pkgs.gtk4
    pkgs.python3Packages.pygobject3
    pkgs.python3Packages.flask  # Für eine eventuelle Web-API
    pkgs.python3Packages.requests  # Für REST-API-Kommunikation
    pkgs.python3Packages.click  # Für CLI-Integration
    pkgs.python3Packages.pytest  # Tests
    pkgs.python3Packages.flake8  # Code-Qualität
    pkgs.python3Packages.black  # Code-Formatierung
    pkgs.python3Packages.mypy  # Typüberprüfung
    pkgs.python3Packages.pdoc  # Dokumentation
    pkgs.python3Packages.psutil  # Für Systemüberwachung
    pkgs.python312Packages.tkinter
    pkgs.gobject-introspection
    pkgs.dbus  # Kommunikation mit Systemdiensten
    pkgs.pkg-config  # Automatische Konfiguration von Compiler- und Linkerflags
    pkgs.glib
    pkgs.git  # Versionskontrolle
    pkgs.makeWrapper  # Zum Erstellen von Aliases
  ];

  nativeBuildInputs = [
    pkgs.pkg-config
  ];

  # Shell customizations
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

  '';
}
