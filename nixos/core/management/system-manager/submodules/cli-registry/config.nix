{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = config.core.management.system-manager.submodules.cli-registry or {};
  configHelpers = import ../../../module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./command-center-config.nix;

  # Import utilities
  ccLib = import ./lib { inherit lib; };

  # Import scripts from scripts/ directory
  mainScript = import ./scripts/main-script.nix { inherit config lib pkgs systemConfig; };
  aliases = import ./scripts/aliases.nix { inherit config lib pkgs systemConfig; };

  # Automatisch alle verwendeten Kategorien sammeln
  # CRITICAL: Use the final resolved commands from systemConfig, not the initial cfg.commands
  finalCommands = config.core.management.system-manager.submodules.cli-registry.commands or [];
  usedCategories = ccLib.utils.getUniqueCategories finalCommands;

in
{
  config = lib.mkMerge [
    (lib.mkIf (cfg.enable or true) (
      (configHelpers.createModuleConfig {
        moduleName = "command-center";
        defaultConfig = defaultConfig;
      }) // {
        # Compute categories from commands
        systemConfig.core.management.system-manager.submodules.cli-registry.categories = usedCategories;
      }
    ))
    (lib.mkIf (cfg.enable or true) {
      # Module implementation (only when enabled)
      environment.systemPackages = [
        mainScript                  # Hauptbefehl
        aliases.nixcc               # Alternative Namen
        aliases.nixctl
        aliases.nix-center
        aliases.nix-control
      ];

      # Assertions for validation (temporarily disabled - commands are registered via systemConfig)
      # assertions = [
      #   {
      #     assertion = cfg.commands != [];
      #     message = "command-center: At least one command must be registered";
      #   }
      # ];
    })
  ];
}

