# Legacy launcher — prefer `ncc modules --gui` via domainGui + registerGuiPage.
# Kept so older references to ncc-modules-gui still resolve.
{ pkgs, getModuleApi, config }:

let
  domainGui = (getModuleApi "gui-engine").domainGui pkgs config;
  nccModulesGui = pkgs.writeShellScriptBin "ncc-modules-gui" ''
    exec ${domainGui}/bin/ncc-domain-gui modules "$@"
  '';
in
{ inherit nccModulesGui; }
