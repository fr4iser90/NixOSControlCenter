{ config, lib, pkgs, systemConfig, moduleConfig, ... }:

let
  configHelpers = import ../../../module-manager/lib/config-helpers.nix {
    inherit pkgs lib;
  };
  # Module name: explizit definieren
  moduleName = "system-update";
  cfg = config.systemConfig.${moduleConfig.${moduleName}.configPath} or {};
  defaultConfig = builtins.readFile ./system-update-config.nix;
in
  lib.mkMerge [
    (lib.mkIf (cfg.enable or true)
      (configHelpers.createModuleConfig {
        moduleName = moduleName;
        defaultConfig = defaultConfig;
      }) // {
        # System update implementation
        # Commands are defined in commands.nix
        # This will be populated from the extracted handler logic
      }
    )
  ]
