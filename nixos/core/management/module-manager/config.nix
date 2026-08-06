# Central Module Management System
{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let

  moduleName = baseNameOf ./. ;        # "module-manager"
  parentName = baseNameOf ../.;        # "management"
  grandparentName = baseNameOf ../../.; # "core"
  configPath = "${grandparentName}.${parentName}.${moduleName}";

  # Cannot use getModuleConfig for self (chicken-egg problem)
  cfg = config.${configPath};
  # Use the template file as default config
  defaultConfig = builtins.readFile ./template-config.nix;

  # Import module discovery and API generation
  discovery = import ./lib/discovery.nix { inherit lib; };
  moduleLib = import ./lib/default.nix { inherit config lib pkgs systemConfig getModuleApi; };

  # Auto-discover modules and generate APIs
  discoveredModules = discovery.discoverAllModules;
  resolvedModules = discovery.resolveDependencies discoveredModules;
  generatedAPIs = discovery.generateAPIs resolvedModules;

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
    }) discoveredModules
  );

  debugModuleConfigs = automaticModuleConfigs;

  # Read central module configuration (v1 modular path)
  configPaths = import ../system-manager/lib/config-paths.nix;
  moduleManagerConfigPath = configPaths.core.management.moduleManager;
  moduleManagerConfig = if builtins.pathExists moduleManagerConfigPath
    then import moduleManagerConfigPath
    else import ./template-config.nix;

  # Helper: Get default config content for a module
  # Uses template file if it exists, otherwise creates minimal config
  # IMPORTANT: Configs must be FLAT - the file path determines nesting automatically!
  getDefaultConfigForModule = module: let
    modulePath = module.path;
    templateFile = "${modulePath}/template-config.nix";
  in
    if builtins.pathExists templateFile then
      builtins.readFile templateFile
    else
      ''
{
  enable = false;
}
'';

  facade = import ../system-manager/lib/config-facade.nix { inherit pkgs; };

  # Seed missing module configs for ALL discovered modules (enable=false defaults OK).
  # Split: create leaf files. Monolith: merge template into systemConfig.nix if attr missing.
  # Never overwrites an existing module entry.
  seedModuleEntries = lib.concatMapStringsSep "\n" (module: let
    moduleSlashPath = lib.replaceStrings [ "." ] [ "/" ] module.configPath;
    defaultConfig = getDefaultConfigForModule module;
    templateFile = pkgs.writeText "ncc-seed-${module.domain}-${module.name}.nix" defaultConfig;
  in ''
    _ncc_seed_one "${moduleSlashPath}" "${templateFile}" "${module.name}"
  '') discoveredModules;

  automaticConfigCreation = {
    system.activationScripts.ncc-seed-module-configs = {
      deps = [ "etc" ];
      text = ''
        # Seed discovered module templates into systemConfig (split or monolith)
        ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}

        _ncc_seed_one() {
          local module_path="$1"
          local template_file="$2"
          local module_name="$3"
          if ncc_module_config_exists "$module_path"; then
            return 0
          fi
          if ncc_write_module_config "$module_path" "$(cat "$template_file")"; then
            echo "ncc: seeded module config for $module_name ($module_path)"
          else
            echo "ncc: failed to seed $module_name ($module_path)" >&2
          fi
        }

        echo "ncc: seeding missing module configs (layout=$(ncc_detect_layout))..."
        ${seedModuleEntries}
      '';
    };
  };


  # Set enable options for all modules based on central config
  # Note: Modules are imported statically in flake.nix, not dynamically here

in {
  imports = [];

  config = lib.mkMerge [
    # CENTRAL REGISTRY: Module-Manager provides paths and APIs for other modules
    # This must be defined early so all modules can use it
    {
      _module.args = {
        modulePaths = {
          backupHelpers = ../system-manager/lib/backup-helpers.nix;
          # CLI formatter API from submodules
          cliApi = ../system-manager/submodules/cli-formatter/lib;
          cliFormatterApi = config.core.management.system-manager.submodules.cli-formatter.api or {};
        };
        # Automatic module configs for all discovered modules
        moduleConfig = debugModuleConfigs;
        
        # Config helpers for automatic config file creation
        configHelpers = import ./lib/config-helpers.nix { inherit pkgs lib; };
        
        # OVERRIDE getModuleConfig to use config (with defaults from options.nix)
        # instead of only systemConfig (without defaults)
        # This ensures that modules get their default values even when config files don't exist yet
        getModuleConfig = moduleName:
          let
            # Get metadata to find the configPath
            hasMetadata = builtins.hasAttr moduleName debugModuleConfigs;
            metadata = if hasMetadata then debugModuleConfigs.${moduleName} else null;
            configPath = if metadata != null then metadata.configPath else null;
            modulePath = if metadata != null then metadata.path else null;
            
            # Get template config as fallback defaults
            templateDefaults = if modulePath != null then
              let
                templateFile = "${modulePath}/template-config.nix";
                # Check if file exists before trying to import
                templateExists = builtins.pathExists templateFile;
                templateContent = if templateExists then
                  let
                    templateImport = builtins.tryEval (import templateFile);
                  in
                    if templateImport.success then templateImport.value else {}
                  else {};
              in
                templateContent
              else {};
            
            # Get config value with defaults from options.nix
            # config.systemConfig.${configPath} contains the evaluated options with defaults
            configValue = if configPath == null then {}
              else lib.attrByPath (["systemConfig"] ++ lib.splitString "." configPath) {} config;
            
            # Get systemConfig value from config files (overrides defaults)
            systemConfigValue = if configPath == null then {}
              else lib.attrByPath (lib.splitString "." configPath) {} systemConfig;
            
            # Merge: template defaults -> config (with defaults from options.nix) -> systemConfig (from files)
            # ALWAYS use templateDefaults as base, even if configValue is not empty
            # This ensures template defaults are always available
            merged = lib.recursiveUpdate templateDefaults configValue;
            result = lib.recursiveUpdate merged systemConfigValue;
          in
            result;
        
        # Generic function to get module config from configPath (with defaults)
        # Usage: cfg = getModuleConfigFromPath moduleConfig.configPath;
        getModuleConfigFromPath = configPath:
          let
            # Get template config as fallback defaults (need to find modulePath from configPath)
            # This is more complex, so we'll just use configValue and systemConfigValue
            configValue = lib.attrByPath (["systemConfig"] ++ lib.splitString "." configPath) {} config;
            systemConfigValue = lib.attrByPath (lib.splitString "." configPath) {} systemConfig;
          in
            lib.recursiveUpdate configValue systemConfigValue;
      };

      # Module-manager configuration (generic path)
      ${configPath} = { };
    }
    # AUTOMATIC CONFIG CREATION: Create default configs for all discovered modules
    # This runs on every nixos-rebuild switch and creates configs if they don't exist
    automaticConfigCreation
  ];
}