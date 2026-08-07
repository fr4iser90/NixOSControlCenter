{ config, lib, pkgs, getModuleConfig, getModuleApi, getCurrentModuleMetadata, moduleName, ... }:
let
  cfg = getModuleConfig moduleName;
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
  formatter = getModuleApi "cli-formatter";
  registry = getModuleApi "cli-registry";
in
{
  config = {
    ${configPath}.api = {
      inherit formatter registry;
      format = formatter;
    };
  };
}
