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
    else import ./template-config.nix;

  # Helper: Get default config content for a module
  # Uses template file if it exists, otherwise creates minimal config
  # IMPORTANT: Configs must be FLAT - the file path determines nesting automatically!
  getDefaultConfigForModule = module: let
    modulePath = module.path;
    templateFile = "${modulePath}/template-config.nix";
  in
    if builtins.pathExists templateFile then
      # Template exists - use it as-is (should be flat, but we trust the template)
      builtins.readFile templateFile
    else
      # Create minimal FLAT config with enable = false
      # The file path will automatically nest it correctly via config-loader
      ''
{
  enable = false;
}
'';

  # Helper: Build config file path from module category
  # category is like "modules.infrastructure.homelab" -> /etc/nixos/configs/modules/infrastructure/homelab/config.nix
  buildConfigFilePath = module: let
    categoryParts = lib.splitString "." module.category;
    configDir = lib.concatStringsSep "/" (["/etc/nixos/configs"] ++ categoryParts);
  in
    "${configDir}/config.nix";

  # Create activation scripts for ALL discovered modules to auto-create default configs
  automaticConfigCreation = lib.mkMerge (
    map (module: let
      defaultConfig = getDefaultConfigForModule module;
      configFilePath = buildConfigFilePath module;
      categoryParts = lib.splitString "." module.category;
      configDir = lib.concatStringsSep "/" (["/etc/nixos/configs"] ++ categoryParts);
      scriptName = "${module.domain}-${lib.replaceStrings ["."] ["-"] module.category}-config-setup";
    in
      {
        system.activationScripts.${scriptName} = {
          text = ''
            mkdir -p "${configDir}"
            if [ ! -f "${configFilePath}" ]; then
              cat << 'EOF' > "${configFilePath}"
${defaultConfig}
EOF
              chmod 644 "${configFilePath}"
              echo "Created default config for ${module.name} at ${configFilePath}"
            fi
          '';
          deps = [];
        };
      }
    ) debugDiscovered
  );

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
            # DEBUG: All logs in the return value to ensure they're evaluated
            builtins.trace "DEBUG: [getModuleConfig] ${moduleName}: hasMetadata=${toString hasMetadata}, configPath=${toString configPath}, modulePath=${toString modulePath}" (
              builtins.trace "DEBUG: [getModuleConfig] ${moduleName}: templateDefaults=${builtins.toJSON templateDefaults}" (
                builtins.trace "DEBUG: [getModuleConfig] ${moduleName}: configValue=${builtins.toJSON configValue}, systemConfigValue=${builtins.toJSON systemConfigValue}" (
                  builtins.trace "DEBUG: [getModuleConfig] ${moduleName}: result=${builtins.toJSON result}" result
                )
              )
            );
        
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