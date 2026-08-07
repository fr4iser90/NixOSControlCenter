# GUI Engine API — getModuleApi "gui-engine"
# Peer module paths via getModuleMetadata — never relative ../../other-module
{ lib, metadata, getModuleMetadata }:

let
  packagesRoot = (getModuleMetadata "packages").path;
  assistantRoot = (getModuleMetadata "ncc-assistant").path;
in
{
  package = pkgs: import ./package.nix { inherit pkgs; };

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
