{ config, lib, pkgs, getCurrentModuleMetadata, getModuleMetadata, ... }:

let
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
  apiValue = import ./api.nix { inherit lib getModuleMetadata; metadata = metadata; };
in {
  config.${configPath}.api = apiValue;
}
