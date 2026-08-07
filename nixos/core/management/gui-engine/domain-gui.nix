# Shared domain GUI binary: `ncc-domain-gui <page>` (+ AI embed sources)
# Peer roots come from getModuleMetadata (via gui-engine api) — no relative cross-module imports.
{ pkgs, getModuleMetadata, packagesRoot, assistantRoot }:

let
  eng = import ./package.nix { inherit pkgs; };
  catalogFile = import "${packagesRoot}/lib/mk-catalog-json.nix" { inherit pkgs; };
  packagesCli = import "${packagesRoot}/scripts/ncc-packages.nix" {
    inherit pkgs getModuleMetadata;
  };
  assistantSrc = "${assistantRoot}/python/ncc_assistant";

  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    pyside6
    httpx
    mcp
  ]);

  src = pkgs.runCommand "ncc-domain-gui-src" { } ''
    mkdir -p $out
    cp -r ${eng.src}/ncc_gui $out/ncc_gui
    cp -r ${assistantSrc} $out/ncc_assistant
  '';

  nccDomainGui = pkgs.writeShellScriptBin "ncc-domain-gui" ''
    set -euo pipefail
    export PYTHONPATH="${src}''${PYTHONPATH:+:$PYTHONPATH}"
    export NCC_PACKAGES_BIN="${packagesCli}/bin/ncc-packages"
    export NCC_PACKAGES_CATALOG="${catalogFile}"
    export QT_QPA_PLATFORM="''${QT_QPA_PLATFORM:-xcb}"
    export PATH="${packagesCli}/bin:${pkgs.nix}/bin:$PATH"
    exec ${pythonEnv}/bin/python -m ncc_gui.domain_gui "$@"
  '';
in
{
  inherit nccDomainGui src pythonEnv;
}
