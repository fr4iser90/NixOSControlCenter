{ config, lib, pkgs, systemConfig, ... }:
let
  configHelpers = import ../../management/module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Module name for API/Discovery
  moduleName = "packages";
  # Import module config for automatic path resolution
  moduleConfig = import ../../management/module-manager/lib/module-config.nix { inherit lib; };
  cfg = config.systemConfig.${moduleConfig.${moduleName}.configPath} or {};
  # Use the template file as default config
  defaultConfig = builtins.readFile ./packages-config.nix;
in
{
  config = lib.mkMerge [
    # Create config on activation (always runs)
    # Uses new external config system
    (configHelpers.createModuleConfig {
      moduleName = moduleName;
      defaultConfig = defaultConfig;
    })
    (lib.mkIf (cfg.enable or false) {
      # Packages configuration will be handled in default.nix
    })
  ];
}
