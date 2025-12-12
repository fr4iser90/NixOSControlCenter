{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.core.management.module-manager or {};
  configHelpers = import ./lib/config-helpers.nix { inherit pkgs lib; backupHelpers = import ../system-manager/lib/backup-helpers.nix { inherit pkgs lib; }; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./module-manager-config.nix;
in
  lib.mkMerge [
    (lib.mkIf (cfg.enable or true) {
      # Create config on activation (always runs)
      # Uses new external config system
      (configHelpers.createModuleConfig {
        moduleName = "module-manager";
        defaultConfig = defaultConfig;
      });
    })
    # Module-manager is a core module that dynamically discovers all available modules
    # No additional system configuration needed - works dynamically
  ]

