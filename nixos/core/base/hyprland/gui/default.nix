# Hyprland GUI — thin wrapper around shared gui-engine + rice store page
{ pkgs, hyprlandCli, getModuleApi, config }:

let
  shared = (getModuleApi "gui-engine").domainGuiBundle pkgs config;
  catalogFile = import ../lib/mk-catalog-json.nix { inherit pkgs; };
in {
  nccHyprlandGui = pkgs.writeShellScriptBin "ncc-hyprland-gui" ''
    set -euo pipefail
    export PYTHONPATH="${shared.src}''${PYTHONPATH:+:$PYTHONPATH}"
    export NCC_HYPRLAND_BIN="${hyprlandCli}/bin/ncc-hyprland"
    export NCC_HYPRLAND_CATALOG="${catalogFile}"
    export QT_QPA_PLATFORM="''${QT_QPA_PLATFORM:-xcb}"
    export PATH="${hyprlandCli}/bin:${pkgs.nix}/bin:$PATH"
    exec ${shared.pythonEnv}/bin/python -m ncc_gui.domain_gui hyprland
  '';
  inherit (shared) pythonEnv src;
  inherit catalogFile;
}
