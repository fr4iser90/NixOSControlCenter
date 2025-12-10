{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.features or {};
  
  # ⭐ AUTO-DISCOVERY: Automatically read all features from directory
  # Note: system-updater is now in core/, not features/
  allFeatureDirs = builtins.readDir ./.;
  categoryDirs = lib.filterAttrs (name: type:
    type == "directory"
  ) allFeatureDirs;

  # Flatten feature module map to include full feature names
  flattenFeatureModules = category: categoryPath:
    let
      categoryContents = builtins.readDir categoryPath;
      featureDirs = lib.filterAttrs (name: type:
        type == "directory"
      ) categoryContents;
    in
      lib.mapAttrs' (name: type:
        lib.nameValuePair "${category}.${name}" (categoryPath + "/${name}")
      ) featureDirs;

  featureModuleMap = lib.concatMapAttrs (category: type:
    flattenFeatureModules category (./. + "/${category}")
  ) categoryDirs;
  
  # Check if homelab-manager should be auto-activated
  # Auto-activate if:
  # - features.homelab-manager = true (manual activation), OR
  # - homelab.swarm == null (Single-Server), OR
  # - homelab.swarm.role == "manager" (Swarm Manager)
  # Do NOT activate if homelab.swarm.role == "worker" (Swarm Worker)
  homelabSwarm = systemConfig.homelab.swarm or null;
  isSwarmManager = homelabSwarm != null && (homelabSwarm.role or null) == "manager";
  isSingleServer = homelabSwarm == null;
  
  shouldActivateHomelabManager = (cfg.homelab-manager or false)  # Manual activation
    || (isSingleServer && (systemConfig.homelab or null) != null)  # Single-Server homelab
    || isSwarmManager;  # Swarm Manager
  
  # AUTO-REGISTRATION: Automatically read active features from systemConfig.features
  # Special handling for homelab-manager (auto-activation logic)
  # Filter out system-updater (now in core/, not features/)

  # Flatten nested features structure to get enabled features
  flattenFeatures = category: features:
    lib.mapAttrs' (name: config:
      lib.nameValuePair "${category}.${name}" (config.enable or false)
    ) features;

  # Get all enabled features from nested structure
  baseActiveFeatures = lib.concatMapAttrs (category: features:
    if lib.isAttrs features then flattenFeatures category features else {}
  ) cfg;
  activeFeaturesWithHomelab = baseActiveFeatures // {
    # Override homelab-manager with special auto-activation logic
    "homelab-manager" = shouldActivateHomelabManager;
  };
  # Filter to only enabled features
  activeFeatures = lib.filterAttrs (name: enabled: enabled) activeFeaturesWithHomelab;
  
  activeFeatureNames = lib.attrNames activeFeatures;
  
  # Remove duplicates
  uniqueFeatures = lib.unique activeFeatureNames;
  
  # Validate that all features exist in featureModuleMap
  validateFeatures = features:
    let
      missing = lib.filter (f: !featureModuleMap ? ${f}) features;
    in
      if missing != [] then
        throw "Unknown features: ${lib.concatStringsSep ", " missing}. Available: ${lib.concatStringsSep ", " (lib.attrNames featureModuleMap)}"
      else features;
  
  # Check conflicts (now reads from modules themselves)
  checkConflicts = features:
    let
      # Read conflicts from each module's _conflicts option
      allConflicts = lib.flatten (map (featureName:
        let
          parts = lib.splitString "." featureName;
          category = lib.head parts;
          moduleName = lib.concatStringsSep "." (lib.tail parts);
          cfg = systemConfig.features.${category}.${moduleName} or {};
        in
          cfg._conflicts or []  # Each module defines its own conflicts
      ) features);

      # Check if any conflicts are also enabled
      activeConflicts = lib.filter (conflict: lib.elem conflict features) allConflicts;
      hasConflict = activeConflicts != [];
    in
      if hasConflict then
        throw "Feature conflict detected! Conflicting features: ${lib.concatStringsSep ", " activeConflicts}"
      else features;
  
  # Resolve dependencies recursively - now reads from modules themselves
  resolveDependencies = features:
    let
      allDeps = lib.flatten (map (featureName:
        # Read dependencies directly from the module's _dependencies option
        # Parse feature name to get category (e.g., "infrastructure.homelab" -> "infrastructure")
        let
          parts = lib.splitString "." featureName;
          category = lib.head parts;
          moduleName = lib.concatStringsSep "." (lib.tail parts);
          cfg = systemConfig.features.${category}.${moduleName} or {};
        in
          cfg._dependencies or []  # Each module defines its own dependencies
      ) features);
      missingDeps = lib.filter (d: !lib.elem d features) allDeps;
    in
      if missingDeps == [] then features
      else resolveDependencies (features ++ missingDeps);
  
  # Get all features including dependencies (with validation and conflict checking)
  validatedFeatures = validateFeatures uniqueFeatures;
  resolvedFeatures = resolveDependencies validatedFeatures;
  # Validate resolved dependencies also exist (catch missing dependency definitions)
  allFeatures = validateFeatures (checkConflicts resolvedFeatures);
  
  # Sort features: dependencies first, then features that depend on them
  # This ensures options are defined before they're used in let blocks
  sortFeaturesByDependencies = features:
    let
      # Get all dependencies for a feature (transitive) - now from modules themselves
      getAllDeps = featureName:
        let
          # Parse feature name to get category and module
          parts = lib.splitString "." featureName;
          category = lib.head parts;
          moduleName = lib.concatStringsSep "." (lib.tail parts);
          cfg = systemConfig.features.${category}.${moduleName} or {};
          directDeps = cfg._dependencies or [];
          transitiveDeps = lib.flatten (map getAllDeps directDeps);
        in
          lib.unique (directDeps ++ transitiveDeps);

      # Calculate dependency depth (how many dependencies a feature has)
      getDepth = feature: lib.length (getAllDeps feature);

      # Sort by depth (features with fewer dependencies come first - dependencies before dependents)
      sorted = lib.sort (a: b: getDepth a < getDepth b) features;
    in
      sorted;
  
  sortedFeatures = sortFeaturesByDependencies allFeatures;
  
  # Convert feature names to module paths
  featureModules = map (feature: featureModuleMap.${feature}) sortedFeatures;
  
in {
  imports = featureModules;
  
  config = {
    # CLI formatter and command-center are Core modules, no enable needed
    
    # Nix experimental features
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
  };
}
