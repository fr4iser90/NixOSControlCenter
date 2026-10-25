# Shared domain GUI binary: `ncc-domain-gui <page>` (+ AI embed sources)
# Peer roots come from getModuleMetadata (via gui-engine api) — no relative cross-module imports.
# Domain pages come from cli-registry guiPages (each module’s ui/gui/).
# Domain catalogs come from cli-registry guiEnvs (registerGuiEnv) — no peer hardwires.
{ pkgs, lib, getModuleMetadata, getModuleApi, packagesRoot, assistantRoot, guiPages ? {}, guiEnvs ? {} }:

let
  eng = import ./package.nix { inherit pkgs; };
  catalogFile = import "${packagesRoot}/lib/mk-catalog-json.nix" { inherit pkgs; };
  packagesCli = import "${packagesRoot}/scripts/ncc-packages.nix" {
    inherit pkgs getModuleMetadata getModuleApi;
  };
  # ncc-assistant ships one package per purpose (see its doc/layout.md), all importable from
  # the staging root — there is no single ncc_assistant package to copy any more.
  assistantPackages = [
    "core"
    "companion"
    "window"
    "tray"
    "widgets"
    "harness"
    "plugins"
    "cli"
  ];
  pagesPkg = import ./lib/mk-domain-pages.nix { inherit lib pkgs guiPages; };
  expectedConfigVersion =
    (import "${(getModuleMetadata "system-manager").path}/components/config-migration/schema.nix" {
      inherit lib;
    }).currentVersion;
  exportDomainEnvs = import ./lib/export-gui-envs.nix { inherit lib; } guiEnvs;

  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    pyside6
    pyte
    httpx
    mcp
  ]);

  src = pkgs.runCommand "ncc-domain-gui-src" { } ''
    mkdir -p $out
    cp -r ${eng.src}/ncc_gui $out/ncc_gui
    ${lib.concatStringsSep "\n    " (map (p: "cp -r ${assistantRoot}/${p} $out/${p}")) assistantPackages}
    cp -r ${assistantRoot}/data $out/data
    cp -r ${pagesPkg}/ncc_domain_page $out/ncc_domain_page
  '';

  nccDomainGui = pkgs.writeShellScriptBin "ncc-domain-gui" ''
    set -euo pipefail
    export PYTHONPATH="${src}''${PYTHONPATH:+:$PYTHONPATH}"
    # Catalogs left the package, so the loader root must be named here too — unset would make
    # every catalog read return [] silently instead of failing.
    export NCC_DATA_ROOT="${src}/data"
    export NCC_PROMPTS_ROOT="${src}/data/prompts"
    export NCC_PACKAGES_BIN="${packagesCli}/bin/ncc-packages"
    export NCC_PACKAGES_CATALOG="${catalogFile}"
    export NCC_GUI_ICON="''${NCC_GUI_ICON:-${eng.iconPng}}"
    export NCC_EXPECTED_CONFIG_VERSION="${expectedConfigVersion}"
    export QT_QPA_PLATFORM="''${QT_QPA_PLATFORM:-xcb}"
    export PATH="${packagesCli}/bin:${pkgs.nix}/bin:$PATH"
    ${exportDomainEnvs}
    exec ${pythonEnv}/bin/python -m ncc_gui.domain_gui "$@"
  '';
in
{
  inherit nccDomainGui src pythonEnv pagesPkg;
}
