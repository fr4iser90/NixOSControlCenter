# GUI Engine API — getModuleApi "gui-engine"
# Peer module paths via getModuleMetadata — never relative ../../other-module
{ lib, metadata, getModuleMetadata }:

let
  packagesRoot = (getModuleMetadata "packages").path;
  assistantRoot = (getModuleMetadata "ncc-assistant").path;
in
{
  package = pkgs: import ./package.nix { inherit pkgs; };

  disabledHint = import ./lib/disabled-hint.nix;

  # Mirror tui-engine: null = auto from desktop.enable (GUI on when desktop on).
  isEnabled = getModuleConfig:
    let
      gui = getModuleConfig "gui-engine";
      desktop = getModuleConfig "desktop";
      raw = gui.enable or null;
      desktopEnable = desktop.enable or null;
    in
      if raw != null then raw
      else if desktopEnable == null then false
      else desktopEnable;

  domainGui = pkgs: (import ./domain-gui.nix {
    inherit pkgs getModuleMetadata packagesRoot assistantRoot;
  }).nccDomainGui;

  rootGui = pkgs: (import ./root-gui.nix {
    inherit pkgs getModuleMetadata packagesRoot;
  }).nccGui;

  domainGuiBundle = pkgs: import ./domain-gui.nix {
    inherit pkgs getModuleMetadata packagesRoot assistantRoot;
  };
}
