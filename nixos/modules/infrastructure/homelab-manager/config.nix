{ config, lib, pkgs, systemConfig, getModuleConfigFromPath, getCurrentModuleMetadata, ... }:

let
  # Get module metadata (generic, not hardcoded)
  moduleConfig = getCurrentModuleMetadata ./.;
  # Generic: Use getModuleConfigFromPath to get config with defaults from options.nix
  cfg = getModuleConfigFromPath moduleConfig.configPath;
  configHelpers = import ../../../core/management/module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./template-config.nix;
in
{
  config = lib.mkMerge [
    (lib.mkIf (cfg.enable or false) (
      (configHelpers.createModuleConfig {
        moduleName = "homelab";
        defaultConfig = defaultConfig;
      }) // {
        # Enable module by default if system config has it
        # Use configPath.enable (consistent with other modules)
        systemConfig.${moduleConfig.configPath}.enable = lib.mkDefault (cfg.enable or false);
      }
    ))
    # Implementation is handled in default.nix
  ];
}
