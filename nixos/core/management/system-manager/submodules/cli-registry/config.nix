{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.core.management.system-manager.submodules.cli-registry or {};
  configHelpers = import ../../../module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./command-center-config.nix;

  # Import utilities
  ccLib = import ./lib { inherit lib; };

  # Import scripts from scripts/ directory
  mainScript = import ./scripts/main-script.nix { inherit config lib pkgs systemConfig; };
  aliases = import ./scripts/aliases.nix { inherit config lib pkgs systemConfig; };

  # API definition - always available
  apiValue = {
    commands = config.core.management.system-manager.submodules.cli-registry.commands or [];
    categories = ccLib.utils.getUniqueCategories (config.core.management.system-manager.submodules.cli-registry.commands or []);
  };

in
  lib.mkMerge [
    (lib.mkIf (cfg.enable or true) (
      (configHelpers.createModuleConfig {
        moduleName = "cli-registry";
        defaultConfig = defaultConfig;
      }) // {
        # API is always available (not dependent on cfg.enable)
        core.management.system-manager.submodules.cli-registry = apiValue;
      }
    ))
  ]

