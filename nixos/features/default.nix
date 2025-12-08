{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.features or {};
  metadata = import ./metadata.nix;
  
  # ⭐ AUTO-DISCOVERY: Automatically read all features from directory
  # Note: system-updater is now in core/, not features/
  allFeatureDirs = builtins.readDir ./.;
  featureModuleMap = lib.mapAttrs' (name: type:
    lib.nameValuePair name (./. + "/${name}")
  ) (lib.filterAttrs (name: type: 
    type == "directory"
  ) allFeatureDirs);
  
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
  baseActiveFeatures = lib.filterAttrs (name: enabled: 
    enabled && name != "system-updater"  # system-updater is now core, not a feature
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
  
  # Check conflicts (like packages system)
  checkConflicts = features:
    let
      conflicts = lib.flatten (map (f:
        let meta = metadata.features.${f} or {};
        in meta.conflicts or []
      ) features);
      hasConflict = lib.any (f: lib.elem f features) conflicts;
    in
      if hasConflict then
        throw "Feature conflict detected! Conflicting features: ${lib.concatStringsSep ", " (lib.intersectLists features conflicts)}"
      else features;
  
  # Resolve dependencies recursively
  resolveDependencies = features:
    let
      allDeps = lib.flatten (map (f:
        let meta = metadata.features.${f} or {};
        in meta.dependencies or []
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
      # Get all dependencies for a feature (transitive)
      getAllDeps = feature:
        let
          directDeps = (metadata.features.${feature} or {}).dependencies or [];
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
