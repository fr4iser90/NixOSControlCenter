{ config, lib, ... }:

with lib;

let
  # Auto-Discovery: Get versions automatically from options.nix
  # Supports both Core modules (systemConfig.*) and Feature modules (features.*)
  # TWO VERSIONS: moduleVersion (code version) and stableVersion (stable, optional)
  # We read moduleVersion from the _version.default in options, since _version.default = moduleVersion
  
  # Get available versions for a module (Core or Feature)
  # moduleType: "core" or "feature"
  # moduleName: name of the module
  getAvailableVersions = moduleType: moduleName:
    let
      basePath = if moduleType == "core" then ../../../core/${moduleName}
                 else ../../../features/${moduleName};
      optionsFile = basePath + "/options.nix";
      # Evaluate the options.nix file
      optionsModule = tryEval (import optionsFile { inherit lib; });
    in if optionsModule.success then
      let
        evaluated = optionsModule.value;
        # Try to get moduleVersion from the options structure
        # For Core: options.systemConfig.<moduleName>._version
        # For Features: options.features.<moduleName>._version
        optionPath = if moduleType == "core" 
                    then evaluated.options.systemConfig.${moduleName}._version.default or "1.0"
                    else evaluated.options.features.${moduleName}._version.default or "1.0";
        versionOption = tryEval optionPath;
        moduleVersion = if versionOption.success then versionOption.value else "1.0";
        # Try to get stableVersion (optional, defaults to moduleVersion)
        stableVersionPath = if moduleType == "core"
                           then evaluated.options.systemConfig.${moduleName}.stableVersion.default or moduleVersion
                           else evaluated.options.features.${moduleName}.stableVersion.default or moduleVersion;
        stableVersionOption = tryEval stableVersionPath;
        stableVersion = if stableVersionOption.success then stableVersionOption.value else moduleVersion;
      in {
        available = moduleVersion;  # Available version in Git (code version)
        stable = stableVersion;  # Stable version (tested, optional)
      }
    else {
      available = "unknown";
      stable = "unknown";
    };
  
  # Auto-Discovery: Find available migrations through directory scan
  # Supports both Core and Feature modules
  getAvailableMigrations = moduleType: moduleName:
    let
      basePath = if moduleType == "core" then ../../../core/${moduleName}
                 else ../../../features/${moduleName};
      migrationsDir = basePath + "/migrations";
      # Scan migrations directory for all vX-to-vY.nix files
      allFiles = tryEval (builtins.readDir migrationsDir);
    in if allFiles.success then
      lib.mapAttrsToList (name: _: 
        # Parse "v1.0-to-v2.0.nix" → { from = "1.0"; to = "2.0"; }
        let
          parts = lib.splitString "-to-v" (lib.removeSuffix ".nix" name);
          from = lib.removePrefix "v" (lib.elemAt parts 0);
          to = lib.elemAt parts 1;
        in { inherit from to; path = migrationsDir + "/${name}"; }
      ) (lib.filterAttrs (name: _: lib.hasSuffix ".nix" name) allFiles.value)
    else [];
  
  # Collect INSTALLED versions from config (User System)
  # "installed" = what's on the system
  # Core modules: from config.systemConfig.*
  # Feature modules: from config.features.*
  installedCoreVersions = lib.mapAttrs (name: cfg: 
    cfg._version or "unknown"
  ) (config.systemConfig or {});
  
  installedFeatureVersions = lib.mapAttrs (name: cfg: 
    cfg._version or "unknown"
  ) (config.features or {});
  
  # Get all module names
  allCoreModuleNames = lib.filter (name: name != "_version") (lib.attrNames (config.systemConfig or {}));
  allFeatureModuleNames = lib.attrNames (config.features or {});
  
  # Get AVAILABLE versions (automatically from options.nix)
  # "available" = what's in Git/repository
  availableCoreVersions = lib.genAttrs allCoreModuleNames (name:
    getAvailableVersions "core" name
  );
  
  availableFeatureVersions = lib.genAttrs allFeatureModuleNames (name:
    getAvailableVersions "feature" name
  );
  
  # Get AVAILABLE migrations (automatically through directory scan)
  availableCoreMigrations = lib.genAttrs allCoreModuleNames (name:
    getAvailableMigrations "core" name
  );
  
  availableFeatureMigrations = lib.genAttrs allFeatureModuleNames (name:
    getAvailableMigrations "feature" name
  );
  
  # Compare versions (simple string comparison for now)
  # Returns: -1 (v1 < v2), 0 (v1 == v2), 1 (v1 > v2)
  compareVersions = v1: v2:
    if v1 == "unknown" || v2 == "unknown" then 0  # Can't compare unknown
    else if v1 == v2 then 0
    else if lib.versionOlder v1 v2 then -1
    else 1;
  
  # Check if update is available
  needsUpdate = installed: available: stable:
    if installed == "unknown" || available == "unknown" then false
    else compareVersions installed available < 0;
  
  # Find migration chain (supports upgrade and downgrade)
  # Returns: [version1, version2, ...] or null if no chain found
  findMigrationChain = moduleType: moduleName: fromVersion: toVersion:
    let
      migrations = if moduleType == "core" 
                   then availableCoreMigrations.${moduleName} or []
                   else availableFeatureMigrations.${moduleName} or [];
      
      # Parse migration: "v1.0-to-v2.0.nix" → { from = "1.0"; to = "2.0"; }
      parseMigration = m: { inherit (m) from to path; };
      parsedMigrations = map parseMigration migrations;
      
      # Check if direct migration exists
      directMigration = lib.findFirst (m: m.from == fromVersion && m.to == toVersion) null parsedMigrations;
      
      # Recursive function to find chain (BFS)
      findChainRecursive = from: to: visited: path:
        if from == to then path  # Found target
        else if lib.elem from visited then null  # Cycle detected
        else
          let
            # Find all migrations starting from current version
            nextSteps = lib.filter (m: m.from == from) parsedMigrations;
            # Try each next step
            results = lib.filter (r: r != null) (map (m:
              findChainRecursive m.to to (visited ++ [from]) (path ++ [m.to])
            ) nextSteps);
          in
            if results != [] then lib.head results
            else null;
      
      # Check if downgrade (toVersion < fromVersion)
      isDowngrade = compareVersions toVersion fromVersion < 0;
      
      # For downgrade, we need to reverse the migration chain
      # Find chain backwards: from toVersion to fromVersion, then reverse
      downgradeChain = if isDowngrade then
        let
          reverseChain = findChainRecursive toVersion fromVersion [] [toVersion];
        in if reverseChain != null then lib.reverseList reverseChain else null
      else null;
      
      # For upgrade, find chain forward
      upgradeChain = if !isDowngrade then
        findChainRecursive fromVersion toVersion [] [fromVersion]
      else null;
    in
      if directMigration != null then [fromVersion toVersion]  # Direct migration exists
      else if upgradeChain != null then upgradeChain
      else if downgradeChain != null then downgradeChain
      else null;
  
  # Check if migration exists (direct or chain)
  hasMigration = moduleType: moduleName: fromVersion: toVersion:
    (findMigrationChain moduleType moduleName fromVersion toVersion) != null;
  
  # Get update strategy for a module
  # Returns: "unknown" | "current" | "auto" | "manual"
  getUpdateStrategy = moduleType: moduleName:
    let
      installedVersions = if moduleType == "core" then installedCoreVersions else installedFeatureVersions;
      availableVersions = if moduleType == "core" then availableCoreVersions else availableFeatureVersions;
      installed = installedVersions.${moduleName} or "unknown";
      available = availableVersions.${moduleName}.available or "unknown";
      hasUpdate = needsUpdate installed available "unknown";
      migrationChain = if installed != "unknown" && available != "unknown" then
        findMigrationChain moduleType moduleName installed available
      else null;
    in
      if installed == "unknown" || available == "unknown" then "unknown"
      else if !hasUpdate then "current"
      else if migrationChain != null then "auto"
      else "manual";
  
  # Get update status for a module
  getUpdateStatus = moduleType: moduleName:
    let
      installedVersions = if moduleType == "core" then installedCoreVersions else installedFeatureVersions;
      availableVersions = if moduleType == "core" then availableCoreVersions else availableFeatureVersions;
      availableMigrations = if moduleType == "core" then availableCoreMigrations else availableFeatureMigrations;
      installed = installedVersions.${moduleName} or "unknown";
      available = availableVersions.${moduleName}.available or "unknown";
      stable = availableVersions.${moduleName}.stable or "unknown";
      migrations = availableMigrations.${moduleName} or [];
      hasUpdate = needsUpdate installed available stable;
      migrationChain = if installed != "unknown" && available != "unknown" then
        findMigrationChain moduleType moduleName installed available
      else null;
      hasMigrationPath = migrationChain != null;
    in {
      installed = installed;
      available = available;
      stable = stable;
      migrations = migrations;
      migrationChain = migrationChain;
      needsUpdate = hasUpdate;
      hasMigration = hasMigrationPath;
      status = if installed == "unknown" then "unknown"
               else if !hasUpdate then "current"
               else if hasMigrationPath then "auto"
               else "manual";
    };
  
  # Combine for comparison - all module versions with status
  coreModuleVersions = lib.genAttrs allCoreModuleNames (name:
    getUpdateStatus "core" name
  );
  
  featureModuleVersions = lib.genAttrs allFeatureModuleNames (name:
    getUpdateStatus "feature" name
  );
  
  # Combined module versions (for backward compatibility and convenience)
  moduleVersions = coreModuleVersions // {
    features = featureModuleVersions;
  };
  
in {
  # Export version information
  inherit moduleVersions;
  inherit coreModuleVersions;
  inherit featureModuleVersions;
  inherit installedCoreVersions;
  inherit installedFeatureVersions;
  inherit availableCoreVersions;
  inherit availableFeatureVersions;
  inherit availableCoreMigrations;
  inherit availableFeatureMigrations;
  
  # Helper functions
  inherit compareVersions;
  inherit needsUpdate;
  inherit getUpdateStrategy;
  inherit getUpdateStatus;
  inherit findMigrationChain;
  inherit hasMigration;
  inherit getAvailableVersions;
  inherit getAvailableMigrations;
}

