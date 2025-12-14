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

  # Read central module configuration
  moduleManagerConfigPath = "/etc/nixos/configs/module-manager-config.nix";
  moduleManagerConfig = if builtins.pathExists moduleManagerConfigPath
    then import moduleManagerConfigPath
    else import ./module-manager-config.nix;

  # Set enable options for all modules based on central config
  setModuleEnables = lib.concatMap (category:
    let
      categoryModules = moduleManagerConfig.${category} or {};
    in lib.mapAttrsToList (moduleName: enabled:
      {
        name = "systemConfig.${category}.${moduleName}.enable";
        value = enabled;
      }
    ) categoryModules
  ) (builtins.attrNames moduleManagerConfig);

  # Set enable options for all modules based on central config
  # Note: Modules are imported statically in flake.nix, not dynamically here

in {
  imports = [];

  config = lib.mkMerge [
    # 🎯 CENTRAL REGISTRY: Module-Manager provides paths and APIs for other modules
    # This must be defined early so all modules can use it
    {
      _module.args.modulePaths = {
        configHelpers = ./lib/config-helpers.nix;
        backupHelpers = ../system-manager/lib/backup-helpers.nix;
        # CLI formatter API from submodules
        cliApi = ../system-manager/submodules/cli-formatter/lib;
        cliFormatterApi = config.core.management.system-manager.submodules.cli-formatter.api or {};
      };

      # Export generated APIs automatically
      core = generatedAPIs.core // {
        management.module-manager = {
          inherit configHelpers;
          discoveredModules = resolvedModules;
          generatedAPIs = generatedAPIs;
        };
      };
    }

    # Set enable options for all modules based on central config
    (builtins.listToAttrs setModuleEnables)

    (lib.mkIf (cfg.enable or true)
      (configHelpers.createModuleConfig {
        moduleName = "module-manager";
        defaultConfig = defaultConfig;
      })
    )
    # Module-manager is a core module that dynamically discovers all available modules
    # No additional system configuration needed - works dynamically
  ];
}