{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.features;
  metadata = import ./metadata.nix;
  
  # Map feature names to module paths
  featureModuleMap = {
    "terminal-ui" = ./terminal-ui;
    "command-center" = ./command-center;
    "system-checks" = ./system-checks;
    "system-updater" = ./system-updater;
    "system-logger" = ./system-logger;
    "system-config-manager" = ./system-config-manager;
    "system-discovery" = ./system-discovery;
    "homelab-manager" = ./homelab-manager;
    "bootentry-manager" = ./bootentry-manager;
    "ssh-client-manager" = ./ssh-client-manager;
    "ssh-server-manager" = ./ssh-server-manager;
    "vm-manager" = ./vm-manager;
    "ai-workspace" = ./ai-workspace;
  };
  
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
  
  # Get active features from systemConfig
  activeFeatures = lib.filterAttrs (name: enabled: enabled) {
    "system-checks" = cfg.system-checks or false;
    "system-updater" = cfg.system-updater or false;
    "system-logger" = cfg.system-logger or false;
    "system-config-manager" = cfg.system-config-manager or false;
    "system-discovery" = cfg.system-discovery or false;
    "homelab-manager" = shouldActivateHomelabManager;
    "bootentry-manager" = cfg.bootentry-manager or false;
    "ssh-client-manager" = cfg.ssh-client-manager or false;
    "ssh-server-manager" = cfg.ssh-server-manager or false;
    "vm-manager" = cfg.vm-manager or false;
    "ai-workspace" = cfg.ai-workspace or false;
  };
  
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
  
  # CRITICAL: terminal-ui MUST be imported first if any feature is active
  # This ensures options.features.terminal-ui is defined before other modules' let blocks evaluate
  hasAnyFeature = activeFeatureNames != [];
  terminalUIFirst = if hasAnyFeature && lib.elem "terminal-ui" allFeatures then [ ./terminal-ui ] else [];
  otherModules = lib.filter (m: toString m != toString ./terminal-ui) featureModules;
  
in {
  imports = terminalUIFirst ++ otherModules;
  
  config = {
    # Auto-enable terminal-ui when any feature is active
    features.terminal-ui.enable = lib.mkIf (lib.elem "terminal-ui" allFeatures) true;
    
    # Nix experimental features
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
  };
}
