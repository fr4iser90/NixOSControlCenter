# Root NCC GUI launcher
#
# Peer catalogs (hyprland rices, …) come from cli-registry registerGuiEnv —
# never hardwire peer module paths here. A domain page's Python arrives the same way
# (registerGuiPython) as a PYTHONPATH entry composed by domain-gui.nix, so this file needs
# no peer at all and cannot drift from the domain wrapper.
{ pkgs, lib, getModuleMetadata, getModuleApi, packagesRoot, guiPages ? {}, guiEnvs ? {}, guiPython ? {} }:

let
  shared = import ./domain-gui.nix {
    inherit pkgs lib getModuleMetadata getModuleApi packagesRoot guiPages guiEnvs guiPython;
  };
  catalogFile = import "${packagesRoot}/lib/mk-catalog-json.nix" { inherit pkgs; };
  eng = import ./package.nix { inherit pkgs; };
  expectedConfigVersion =
    (import "${(getModuleMetadata "system-manager").path}/components/config-migration/schema.nix" {
      inherit lib;
    }).currentVersion;
  nccGui = pkgs.writeShellScriptBin "ncc-gui" ''
    set -euo pipefail
    export PYTHONPATH="${shared.pythonPath}''${PYTHONPATH:+:$PYTHONPATH}"
    export NCC_PACKAGES_BIN="''${NCC_PACKAGES_BIN:-ncc-packages}"
    export NCC_PACKAGES_CATALOG="''${NCC_PACKAGES_CATALOG:-${catalogFile}}"
    export NCC_GUI_ICON="''${NCC_GUI_ICON:-${eng.iconPng}}"
    export NCC_EXPECTED_CONFIG_VERSION="${expectedConfigVersion}"
    export QT_QPA_PLATFORM="''${QT_QPA_PLATFORM:-xcb}"
    export PATH="${pkgs.nix}/bin:$PATH"
    ${shared.allEnvExports}
    exec ${shared.pythonEnv}/bin/python -c 'from ncc_gui.root import main; raise SystemExit(main())'
  '';
in
{ inherit nccGui; src = shared.src; }
