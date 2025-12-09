{ config, lib, ... }:

with lib;

let
  # 1. Collect ALL module types
  moduleTypes = {
    core = config.systemConfig or {};
    features = config.features or {};
    # custom = config.custom or {};  # If you have custom modules
  };

  # 2. ALL modules in unified structure
  allModules = lib.concatLists (lib.mapAttrsToList (type: modules:
    lib.mapAttrsToList (name: cfg: {
      type = type;
      name = name;
      fullName = "${type}.${name}";
      installed = cfg._version or "unknown";
      config = cfg;
    }) modules
  ) moduleTypes);

  # 3. As map for easy access
  moduleMap = lib.listToAttrs (map (m: {
    name = m.fullName;
    value = m;
  }) allModules);

  # 4. Generic path function
  getModulePath = moduleType: moduleName:
    let
      basePaths = {
        core = ../../../core;
        features = ../../../features;
        # custom = ../../../custom;
      };
      basePath = basePaths.${moduleType} or (throw "Unknown module type: ${moduleType}");
    in basePath + "/${moduleName}";

  # 5. Generic version check
  getAvailableVersions = moduleType: moduleName:
    let
      basePath = getModulePath moduleType moduleName;
      optionsFile = basePath + "/options.nix";
      optionsModule = builtins.tryEval (import optionsFile { inherit lib; });
    in if optionsModule.success then
      let
        evaluated = optionsModule.value;
        # UNIFIED options structure for ALL modules
        optionPath = evaluated.options.${moduleType}.${moduleName}._version.default or "1.0";
        versionOption = builtins.tryEval optionPath;
        moduleVersion = if versionOption.success then versionOption.value else "1.0";
        
        stableVersionPath = evaluated.options.${moduleType}.${moduleName}.stableVersion.default or moduleVersion;
        stableVersionOption = builtins.tryEval stableVersionPath;
        stableVersion = if stableVersionOption.success then stableVersionOption.value else moduleVersion;
      in {
        available = moduleVersion;
        stable = stableVersion;
      }
    else {
      available = "unknown";
      stable = "unknown";
    };
  
  # 6. Generic migration check
  getAvailableMigrations = moduleType: moduleName:
    let
      basePath = getModulePath moduleType moduleName;
      migrationsDir = basePath + "/migrations";
      dirExists = builtins.pathExists migrationsDir;
      allFiles = if dirExists then
        builtins.tryEval (builtins.readDir migrationsDir)
      else { success = false; value = {}; };
    in if allFiles.success then
      lib.mapAttrsToList (name: _: 
        let
          parts = lib.splitString "-to-v" (lib.removeSuffix ".nix" name);
          from = lib.removePrefix "v" (lib.elemAt parts 0);
          to = lib.elemAt parts 1;
        in { inherit from to; path = migrationsDir + "/${name}"; }
      ) (lib.filterAttrs (name: _: lib.hasSuffix ".nix" name) allFiles.value)
    else [];
  
  # 7. Verfügbare Versionen für ALLE Module
  availableModuleVersions = lib.mapAttrs (fullName: module:
    getAvailableVersions module.type module.name
  ) moduleMap;
  
  # 8. Verfügbare Migrationen für ALLE Module
  availableModuleMigrations = lib.mapAttrs (fullName: module:
    getAvailableMigrations module.type module.name
  ) moduleMap;
  
  # 9. Status für ALLE Module berechnen
  moduleStatuses = lib.mapAttrs (fullName: module:
    let
      installed = module.installed;
      available = availableModuleVersions.${fullName}.available or "unknown";
      stable = availableModuleVersions.${fullName}.stable or "unknown";
      migrations = availableModuleMigrations.${fullName} or [];
      
      # Vergleichsfunktion
      compareVersions = v1: v2:
        if v1 == "unknown" || v2 == "unknown" then 0
        else if v1 == v2 then 0
        else if lib.versionOlder v1 v2 then -1
        else 1;
      
      needsUpdate = compareVersions installed available < 0;
      
      # Migration-Kette finden (vereinfacht)
      hasMigration = migrations != [];
      
      status = if installed == "unknown" then "unknown"
               else if !needsUpdate then "current"
               else if hasMigration then "auto"
               else "manual";
    in {
      inherit fullName;
      type = module.type;
      name = module.name;
      inherit installed available stable migrations;
      inherit needsUpdate hasMigration status;
    }
  ) moduleMap;

in {
  # Export ONLY as _module.args
  _module.args = {
    # Unified interfaces
    moduleStatuses = moduleStatuses;
    availableModuleVersions = availableModuleVersions;
    availableModuleMigrations = availableModuleMigrations;

    # Helper functions
    getModuleStatus = fullName: moduleStatuses.${fullName} or null;
    getModuleVersions = moduleType: moduleName: availableModuleVersions."${moduleType}.${moduleName}" or null;
    getModuleMigrations = moduleType: moduleName: availableModuleMigrations."${moduleType}.${moduleName}" or null;

    # For compatibility with existing code
    coreModuleVersions = lib.filterAttrs (n: _: lib.hasPrefix "core." n) moduleStatuses;
    featureModuleVersions = lib.filterAttrs (n: _: lib.hasPrefix "features." n) moduleStatuses;
  };

  # NO options defined here!
}