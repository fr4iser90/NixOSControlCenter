{ config, lib, ... }:

with lib;

let
  # Auto-Discovery: Get versions automatically from options.nix
  # TWO VERSIONS: featureVersion (code version) and stableVersion (stable, optional)
  # We read featureVersion from the _version.default in options, since _version.default = featureVersion
  getAvailableVersions = featureName:
    let
      optionsFile = ../../../features/${featureName}/options.nix;
      # Evaluate the options.nix file
      optionsModule = tryEval (import optionsFile { inherit lib; });
    in if optionsModule.success then
      let
        evaluated = optionsModule.value;
        # Try to get featureVersion from the options structure
        # _version.default should contain featureVersion
        versionOption = tryEval (
          evaluated.options.features.${featureName}._version.default or "1.0"
        );
        featureVersion = if versionOption.success then versionOption.value else "1.0";
        # Try to get stableVersion (optional, defaults to featureVersion)
        stableVersionOption = tryEval (
          evaluated.options.features.${featureName}.stableVersion.default or featureVersion
        );
        stableVersion = if stableVersionOption.success then stableVersionOption.value else featureVersion;
      in {
        available = featureVersion;  # Available version in Git (code version)
        stable = stableVersion;  # Stable version (tested, optional)
      }
    else {
      available = "unknown";
      stable = "unknown";
    };
  
  # Auto-Discovery: Find available migrations through directory scan
  getAvailableMigrations = featureName:
    let
      migrationsDir = ../../../features/${featureName}/migrations;
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
  installedVersions = lib.mapAttrs (name: cfg: 
    cfg._version or "unknown"
  ) config.features;
  
  # Get all feature names (from config.features)
  allFeatureNames = lib.attrNames config.features;
  
  # Get AVAILABLE versions (automatically from options.nix)
  # "available" = what's in Git/repository
  availableVersions = lib.genAttrs allFeatureNames (name:
    getAvailableVersions name
  );
  
  # Get AVAILABLE migrations (automatically through directory scan)
  availableMigrations = lib.genAttrs allFeatureNames (name:
    getAvailableMigrations name
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
  findMigrationChain = featureName: fromVersion: toVersion:
    let
      migrations = availableMigrations.${featureName} or [];
      
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
  hasMigration = featureName: fromVersion: toVersion:
    (findMigrationChain featureName fromVersion toVersion) != null;
  
  # Get update strategy for a feature
  # Returns: "unknown" | "current" | "auto" | "manual"
  getUpdateStrategy = name:
    let
      installed = installedVersions.${name} or "unknown";
      available = availableVersions.${name}.available or "unknown";
      hasUpdate = needsUpdate installed available "unknown";
      migrationChain = if installed != "unknown" && available != "unknown" then
        findMigrationChain name installed available
      else null;
    in
      if installed == "unknown" || available == "unknown" then "unknown"
      else if !hasUpdate then "current"
      else if migrationChain != null then "auto"
      else "manual";
  
  # Get update status for a feature
  getUpdateStatus = name:
    let
      installed = installedVersions.${name} or "unknown";
      available = availableVersions.${name}.available or "unknown";
      stable = availableVersions.${name}.stable or "unknown";
      migrations = availableMigrations.${name} or [];
      hasUpdate = needsUpdate installed available stable;
      migrationChain = if installed != "unknown" && available != "unknown" then
        findMigrationChain name installed available
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
  
  # Combine for comparison - all feature versions with status
  featureVersions = lib.genAttrs allFeatureNames (name:
    getUpdateStatus name
  );
  
in {
  # Export version information
  inherit featureVersions;
  inherit installedVersions;
  inherit availableVersions;
  inherit availableMigrations;
  
  # Helper functions
  inherit compareVersions;
  inherit needsUpdate;
  inherit getUpdateStrategy;
  inherit getUpdateStatus;
  inherit findMigrationChain;
  inherit hasMigration;
}

