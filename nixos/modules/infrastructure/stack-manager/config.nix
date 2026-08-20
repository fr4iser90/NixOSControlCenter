{ config, lib, pkgs, systemConfig, getModuleConfigFromPath, getCurrentModuleMetadata, configHelpers, ... }:

let
  moduleConfig = getCurrentModuleMetadata ./.;
  cfg = getModuleConfigFromPath moduleConfig.configPath;
  defaultConfig = builtins.readFile ./template-config.nix;
in {
  config = lib.mkMerge [
    (lib.mkIf (cfg.enable or false) (
      (configHelpers.createModuleConfig {
        moduleName = "stacks";
        defaultConfig = defaultConfig;
      }) // {
        systemConfig.${moduleConfig.configPath}.enable = lib.mkDefault (cfg.enable or false);
      }
    ))
  ];
}
