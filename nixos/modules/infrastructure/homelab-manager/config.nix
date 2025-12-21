{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.modules.infrastructure.homelab;
  configHelpers = import ../../../core/management/module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./homelab-config.nix;
in
  lib.mkMerge [
    (lib.mkIf (cfg.enable or false) (
      (configHelpers.createModuleConfig {
        moduleName = "homelab";
        defaultConfig = defaultConfig;
      }) // {
        # Enable module by default if system config has it
        modules.infrastructure.homelab.enable = lib.mkDefault (systemConfig.modules.infrastructure.homelab.enable or false);
      }
    ))
    # Implementation is handled in default.nix
  ]
