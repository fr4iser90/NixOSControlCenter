{ pkgs, lib, getModuleApi, getModuleMetadata, config }:

let
  shared = (getModuleApi "gui-engine").domainGuiBundle pkgs config;
  expectedConfigVersion =
    (import "${(getModuleMetadata "system-manager").path}/components/config-migration/schema.nix" {
      inherit lib;
    }).currentVersion;
  nccSystemGui = pkgs.writeShellScriptBin "ncc-system-gui" ''
    set -euo pipefail
    export PYTHONPATH="${shared.src}''${PYTHONPATH:+:$PYTHONPATH}"
    export NCC_EXPECTED_CONFIG_VERSION="${expectedConfigVersion}"
    export QT_QPA_PLATFORM="''${QT_QPA_PLATFORM:-xcb}"
    exec ${shared.pythonEnv}/bin/python -m ncc_gui.domain_gui system
  '';
in
{ inherit nccSystemGui; }
