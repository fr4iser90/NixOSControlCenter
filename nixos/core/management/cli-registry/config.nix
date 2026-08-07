{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getModuleMetadata, getCurrentModuleMetadata, moduleName, ... }:
let
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;

  cfg = getModuleConfig moduleName;
  defaultConfig = builtins.readFile ./template-config.nix;

  ccLib = import ./lib { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };

  mainScript = import ./scripts/main-script.nix {
    inherit config lib pkgs systemConfig getModuleConfig getModuleApi getModuleMetadata getCurrentModuleMetadata moduleName;
  };
  aliases = import ./scripts/aliases.nix {
    inherit config lib pkgs systemConfig getModuleConfig getModuleApi getModuleMetadata getCurrentModuleMetadata moduleName;
  };

  apiValue = import ./api.nix { inherit lib getModuleMetadata; metadata = metadata; };

in
{
  config = {
    ${configPath}.api = apiValue;
    environment.systemPackages = [ mainScript ];
  };
}
