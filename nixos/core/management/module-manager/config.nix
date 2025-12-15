# Zentrales Module-Management System
{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.core.management.module-manager or {};
  configHelpers = import ./lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./module-manager-config.nix;

  # Import module discovery and API generation
  discovery = import ./lib/discovery.nix { inherit lib; };
  moduleLib = import ./lib/default.nix { inherit config lib pkgs systemConfig; };

  # Auto-discover modules and generate APIs
  discoveredModules = discovery.discoverAllModules;
  resolvedModules = discovery.resolveDependencies discoveredModules;
  generatedAPIs = discovery.generateAPIs resolvedModules;

  # DEBUG: Show discovered modules
  debugDiscovered = builtins.trace "DEBUG: discoveredModules count = ${toString (builtins.length discoveredModules)}" (
    builtins.trace "DEBUG: discoveredModules names = ${builtins.toJSON (map (m: m.name) discoveredModules)}" discoveredModules
  );

  # Generate automatic moduleConfig for all discovered modules
  automaticModuleConfigs = lib.listToAttrs (
    map (module: {
      name = module.name;
      value = {
        # Pfade: configPath ist der systemConfig Pfad ohne "systemConfig." prefix
        configPath = module.configPath;
        enablePath = module.enablePath;
        apiPath = module.apiPath;
        name = module.name;
        category = module.category;
        path = module.path;
      };
    }) debugDiscovered
  );

  # DEBUG: Show generated configs
  debugModuleConfigs = builtins.trace "DEBUG: automaticModuleConfigs keys = ${builtins.toJSON (builtins.attrNames automaticModuleConfigs)}" automaticModuleConfigs;

  # Read central module configuration
  moduleManagerConfigPath = "/etc/nixos/configs/module-manager-config.nix";
  moduleManagerConfig = if builtins.pathExists moduleManagerConfigPath
    then import moduleManagerConfigPath
    else import ./module-manager-config.nix;


  # Set enable options for all modules based on central config
  # Note: Modules are imported statically in flake.nix, not dynamically here

in {
  imports = [];

  config = lib.mkMerge [
    # 🎯 CENTRAL REGISTRY: Module-Manager provides paths and APIs for other modules
    # This must be defined early so all modules can use it
    {
      _module.args = {
        modulePaths = {
          configHelpers = ./lib/config-helpers.nix;
          backupHelpers = ../system-manager/lib/backup-helpers.nix;
          # CLI formatter API from submodules
          cliApi = ../system-manager/submodules/cli-formatter/lib;
          cliFormatterApi = config.core.management.system-manager.submodules.cli-formatter.api or {};
        };
        # Automatic module configs for all discovered modules
        moduleConfig = debugModuleConfigs;
      };

      # Module-manager configuration
      core.management.module-manager = {
        inherit configHelpers;
      };
    }


    (lib.mkIf (cfg.enable or true)
      (configHelpers.createModuleConfig {
        moduleName = "module-manager";
        defaultConfig = defaultConfig;
      })
    )
  ];
}