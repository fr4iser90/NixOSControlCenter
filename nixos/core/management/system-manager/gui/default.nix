{ pkgs, getModuleApi, config }:

let
  shared = (getModuleApi "gui-engine").domainGuiBundle pkgs config;
  nccSystemGui = pkgs.writeShellScriptBin "ncc-system-gui" ''
    set -euo pipefail
    export PYTHONPATH="${shared.src}''${PYTHONPATH:+:$PYTHONPATH}"
    export QT_QPA_PLATFORM="''${QT_QPA_PLATFORM:-xcb}"
    exec ${shared.pythonEnv}/bin/python -m ncc_gui.domain_gui system
  '';
in
{ inherit nccSystemGui; }
