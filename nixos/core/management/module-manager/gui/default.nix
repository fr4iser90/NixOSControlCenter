{ pkgs, getModuleApi }:

let
  shared = (getModuleApi "gui-engine").domainGuiBundle pkgs;
  nccModulesGui = pkgs.writeShellScriptBin "ncc-modules-gui" ''
    set -euo pipefail
    export PYTHONPATH="${shared.src}''${PYTHONPATH:+:$PYTHONPATH}"
    export QT_QPA_PLATFORM="''${QT_QPA_PLATFORM:-xcb}"
    exec ${shared.pythonEnv}/bin/python -m ncc_gui.domain_gui modules
  '';
in
{ inherit nccModulesGui; }
