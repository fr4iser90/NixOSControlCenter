# Packages GUI — thin wrapper around shared gui-engine page
{ pkgs, packagesCli, getModuleApi }:

let
  shared = (getModuleApi "gui-engine").domainGuiBundle pkgs;
  catalogFile = import ../lib/mk-catalog-json.nix { inherit pkgs; };

  nccPackagesGui = pkgs.writeShellScriptBin "ncc-packages-gui" ''
    set -euo pipefail
    export PYTHONPATH="${shared.src}''${PYTHONPATH:+:$PYTHONPATH}"
    export NCC_PACKAGES_BIN="${packagesCli}/bin/ncc-packages"
    export NCC_PACKAGES_CATALOG="${catalogFile}"
    export QT_QPA_PLATFORM="''${QT_QPA_PLATFORM:-xcb}"
    export PATH="${packagesCli}/bin:${pkgs.nix}/bin:$PATH"
    exec ${shared.pythonEnv}/bin/python -m ncc_gui.domain_gui packages
  '';
in
{
  inherit nccPackagesGui;
  inherit (shared) pythonEnv src;
  inherit catalogFile;
}
