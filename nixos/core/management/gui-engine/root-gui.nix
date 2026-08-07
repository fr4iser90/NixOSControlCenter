# Root NCC GUI launcher (includes AI assistant sources for embed)
{ pkgs, getModuleMetadata, packagesRoot }:

let
  shared = import ./domain-gui.nix {
    inherit pkgs getModuleMetadata packagesRoot;
    assistantRoot = (getModuleMetadata "ncc-assistant").path;
  };
  catalogFile = import "${packagesRoot}/lib/mk-catalog-json.nix" { inherit pkgs; };
  nccGui = pkgs.writeShellScriptBin "ncc-gui" ''
    set -euo pipefail
    export PYTHONPATH="${shared.src}''${PYTHONPATH:+:$PYTHONPATH}"
    export NCC_PACKAGES_BIN="''${NCC_PACKAGES_BIN:-ncc-packages}"
    export NCC_PACKAGES_CATALOG="''${NCC_PACKAGES_CATALOG:-${catalogFile}}"
    export QT_QPA_PLATFORM="''${QT_QPA_PLATFORM:-xcb}"
    export PATH="${pkgs.nix}/bin:$PATH"
    exec ${shared.pythonEnv}/bin/python -c 'from ncc_gui.root import main; raise SystemExit(main())'
  '';
in
{ inherit nccGui; src = shared.src; }
