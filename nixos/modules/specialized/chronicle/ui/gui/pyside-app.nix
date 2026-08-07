{ lib, pkgs, cfg, getModuleApi }:

let
  guiEngine = (getModuleApi "gui-engine").package pkgs;
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [ pyside6 ]);
  src = pkgs.runCommand "chronicle-gui-src" { } ''
    mkdir -p $out/ncc_gui
    cp -r ${guiEngine.src}/ncc_gui/* $out/ncc_gui/
    cp ${./pyside_app.py} $out/chronicle_gui.py
  '';
in
pkgs.writeShellScriptBin "chronicle-gui" ''
  set -euo pipefail
  export PYTHONPATH="${src}''${PYTHONPATH:+:$PYTHONPATH}"
  export NCC_CHRONICLE_BIN="''${NCC_CHRONICLE_BIN:-chronicle}"
  export QT_QPA_PLATFORM="''${QT_QPA_PLATFORM:-xcb}"
  exec ${pythonEnv}/bin/python ${src}/chronicle_gui.py "$@"
''
