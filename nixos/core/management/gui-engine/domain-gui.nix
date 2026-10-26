# Shared domain GUI binary: `ncc-domain-gui <page>`
# Peer roots come from getModuleMetadata (via gui-engine api) — no relative cross-module imports.
# Domain pages come from cli-registry guiPages (each module’s ui/gui/).
# Domain catalogs come from cli-registry guiEnvs (registerGuiEnv) — no peer hardwires.
# A page’s Python comes from cli-registry guiPython (registerGuiPython): its store root is
# prepended as a PYTHONPATH entry, so this file never copies peer code nor names the packages
# inside it. Peer code stays read-only in the store — importing it needs visibility, not write
# access, and copying it here used to collide with the engine’s own read-only ncc_gui.
{ pkgs, lib, getModuleMetadata, getModuleApi, packagesRoot, guiPages ? {}, guiEnvs ? {}, guiPython ? {} }:

let
  eng = import ./package.nix { inherit pkgs; };
  catalogFile = import "${packagesRoot}/lib/mk-catalog-json.nix" { inherit pkgs; };
  packagesCli = import "${packagesRoot}/scripts/ncc-packages.nix" {
    inherit pkgs getModuleMetadata getModuleApi;
  };
  payloads = lib.attrValues guiPython;
  pagesPkg = import ./lib/mk-domain-pages.nix { inherit lib pkgs guiPages; };
  expectedConfigVersion =
    (import "${(getModuleMetadata "system-manager").path}/components/config-migration/schema.nix" {
      inherit lib;
    }).currentVersion;
  # Payload env rides the same channel as registerGuiEnv output, so both wrappers get it.
  exportDomainEnvs =
    import ./lib/export-gui-envs.nix { inherit lib; }
      (guiEnvs // lib.foldlAttrs (acc: _: p: acc // (p.env or { })) {} guiPython);
  # Paths a payload reads by path (generated indexes): its content can't be tree-hashed
  # here, so the module declares the path and ncc_gui.reload treats a change as hard.
  payloadFingerprint =
    lib.concatStringsSep " " (lib.unique (lib.concatMap (p: p.fingerprint or [ ]) payloads));
  exportPayloadFingerprint = lib.optionalString (payloadFingerprint != "") ''
    export NCC_GUI_FINGERPRINT="${payloadFingerprint}"
  '';

  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    pyside6
    pyte
    httpx
    mcp
  ]);

  src = pkgs.runCommand "ncc-domain-gui-src" { } ''
    mkdir -p $out
    cp -r ${eng.src}/ncc_gui $out/ncc_gui
    cp -r ${pagesPkg}/ncc_domain_page $out/ncc_domain_page
  '';

  # Payload roots stay in the store and become PYTHONPATH entries — peer code is never
  # copied. It is read-only there and an import needs visibility, not write access.
  # The engine's own root comes FIRST: a payload that ships an ncc_gui of its own must not
  # shadow the engine's, and PYTHONPATH resolves left to right.
  payloadRoots = lib.unique (map (p: p.root) payloads);
  pythonPath = lib.concatStringsSep ":" ([ "${src}" ] ++ payloadRoots);

  # Everything a peer contributes to the GUI runtime, in one place so root-gui cannot
  # drift from domain-gui.
  allEnvExports = ''
    ${exportDomainEnvs}
    ${exportPayloadFingerprint}
  '';

  nccDomainGui = pkgs.writeShellScriptBin "ncc-domain-gui" ''
    set -euo pipefail
    export PYTHONPATH="${pythonPath}''${PYTHONPATH:+:$PYTHONPATH}"
    export NCC_PACKAGES_BIN="${packagesCli}/bin/ncc-packages"
    export NCC_PACKAGES_CATALOG="${catalogFile}"
    export NCC_GUI_ICON="''${NCC_GUI_ICON:-${eng.iconPng}}"
    export NCC_EXPECTED_CONFIG_VERSION="${expectedConfigVersion}"
    export QT_QPA_PLATFORM="''${QT_QPA_PLATFORM:-xcb}"
    export PATH="${packagesCli}/bin:${pkgs.nix}/bin:$PATH"
    ${allEnvExports}
    exec ${pythonEnv}/bin/python -m ncc_gui.domain_gui "$@"
  '';
in
{
  inherit nccDomainGui src pythonPath pythonEnv pagesPkg allEnvExports;
}
