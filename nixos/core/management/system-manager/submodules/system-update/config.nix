{ config, lib, pkgs, systemConfig, moduleConfig, ... }:

let
  cfg = systemConfig.${moduleConfig.configPath};
  configHelpers = import ../../../module-manager/lib/config-helpers.nix {
    inherit pkgs lib;
  };
  defaultConfig = builtins.readFile ./system-update-config.nix;
in
  lib.mkMerge [
    (lib.mkIf (cfg.enable or true)
      (configHelpers.createModuleConfig {
        moduleName = "system-update";
        defaultConfig = defaultConfig;
      }) // {
        # System update implementation
        # Commands are defined in commands.nix
        # This will be populated from the extracted handler logic
      }
    )
  ]
