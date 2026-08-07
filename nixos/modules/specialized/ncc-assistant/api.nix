# ncc-assistant API — getModuleApi "ncc-assistant"
{ lib, metadata, getModuleMetadata }:

{
  package = { pkgs, cfg, getModuleApi, getModuleMetadata }:
    import ./package.nix { inherit pkgs lib cfg getModuleApi getModuleMetadata; };
}
