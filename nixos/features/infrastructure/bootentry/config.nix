{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.features.infrastructure.bootentry;
  configHelpers = import ../../../core/management/module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./bootentry-config.nix;
in
  lib.mkMerge [
    (lib.mkIf (cfg.enable or false) {
      # Create config on activation (always runs)
      # Uses new external config system
      (configHelpers.createModuleConfig {
        moduleName = "bootentry";
        defaultConfig = defaultConfig;
      });
    })
    # Boot entry module implementation is handled in default.nix
  ]
