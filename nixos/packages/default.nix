{ config, lib, pkgs, systemConfig, ... }:

let
  # Load metadata
  metadata = import ./metadata.nix;
  
  # Load base packages
  basePackages = {
    desktop = import ./base/desktop.nix;
    server = import ./base/server.nix;
  };

  # Docker mode logic: Determine if root or rootless Docker should be used
  #
  # Default strategy:
  # - Default: "rootless" (safer, sufficient for most cases)
  # - AI-Workspace active → automatically "root" (OCI containers need root)
  # - User can explicitly choose "root" for Swarm
  #
  # Supported values:
  # - false → no Docker
  # - true → Backward compatibility → "rootless" (Default)
  # - "root" → root Docker (for Swarm/OCI containers)
  # - "rootless" → rootless Docker (safer, Default)
  getDockerMode = dockerFeature:
    let
      # AI-Workspace needs root (OCI containers)
      needsRoot = systemConfig.features.ai-workspace or false;
      
      # If "docker" feature active → root
      # If "docker-rootless" feature active → rootless
      dockerValue = if dockerFeature == "docker" then "root"
                    else if dockerFeature == "docker-rootless" then "rootless"
                    else false;
    in
      if dockerValue == false then false
      else if needsRoot then "root"  # AI-Workspace overrides to root
      else dockerValue;  # User choice or Default "rootless"

  # Load preset if set
  presetConfig = if systemConfig.preset or null != null then
    import (./presets + "/${systemConfig.preset}.nix")
  else null;

  # Generic migration: Convert old packageModules Set structure to new features List
  # This works generically for any category/feature combination
  convertOldPackageModules = oldModules:
    let
      # Find feature name by legacy path in metadata
      # Returns feature name or null if not found
      findFeatureByLegacyPath = category: feature:
        let
          legacyPath = "${category}.${feature}";
          # Search all features for matching legacyPath
          matchingFeatures = lib.filterAttrs (name: meta:
            (meta.legacyPath or null) == legacyPath
          ) metadata.features;
        in
          if matchingFeatures != {} then
            lib.head (lib.attrNames matchingFeatures)
          else null;

      # Handle multi-feature legacy handlers (e.g., virtualization → qemu-vm + virt-manager)
      handleLegacyMultiFeature = category: feature: value:
        let
          legacyPath = "${category}.${feature}";
          # Find feature with this legacyPath and multi-feature handler
          matchingFeatures = lib.filterAttrs (name: meta:
            (meta.legacyPath or null) == legacyPath
            && (meta.legacyHandler or null) == "multi-feature"
          ) metadata.features;
        in
          if matchingFeatures != {} && value == true then
            let
              featureName = lib.head (lib.attrNames matchingFeatures);
              # Special case: virtualization → qemu-vm + virt-manager (desktop only)
              baseFeatures = [ featureName ];
              additionalFeatures = if featureName == "qemu-vm" && systemConfig.systemType == "desktop" then
                [ "virt-manager" ]
              else [];
            in
              baseFeatures ++ additionalFeatures
          else [];

      # Convert single category.feature to feature name(s)
      convertFeature = category: feature: value:
        if value != true then []  # Only convert true values
        else
          let
            # First check for multi-feature handler
            multiFeature = handleLegacyMultiFeature category feature value;
          in
            if multiFeature != [] then multiFeature
            else
              let
                # Check metadata for legacyPath
                featureName = findFeatureByLegacyPath category feature;
              in
                if featureName != null then [ featureName ]
                else
                  # Convention: category.feature → feature (automatic for standard cases)
                  [ feature ];

      # Convert all features in a category
      convertCategory = category:
        let
          categoryModules = oldModules.${category} or {};
          features = lib.attrNames categoryModules;
        in
          lib.flatten (map (feature:
            convertFeature category feature (categoryModules.${feature} or false)
          ) features);

      # Convert all categories
      categories = lib.attrNames oldModules;
      allConverted = lib.flatten (map convertCategory categories);
    in
      lib.unique allConverted;  # Remove duplicates

  # Check if old structure (Set) is present
  isOldStructure = systemConfig.packageModules or null != null 
    && !lib.isList (systemConfig.packageModules or null);

  # Convert old structure if needed
  migratedFeatures = if isOldStructure then
    convertOldPackageModules systemConfig.packageModules
  else [];

  # Warning for deprecated structure
  warnMigration = if isOldStructure then
    lib.warn "⚠️  DEPRECATED: packageModules uses old structure. Please migrate to 'features' or 'preset'. Run 'ncc system-update' to auto-migrate."
  else x: x;

  # Combine preset features + additional features + migrated features + new features
  # Note: systemConfig.features is a Set for system features (ai-workspace, etc.), not package features
  allFeatures = 
    (presetConfig.features or [])
    ++ (systemConfig.additionalPackageModules or [])
    ++ (warnMigration migratedFeatures)
    ++ (if !isOldStructure then (systemConfig.packageModules or []) else []);

  # Remove duplicates
  uniqueFeatures = lib.unique allFeatures;

  # Filter features by systemType
  validFeatures = lib.filter (feature:
    let meta = metadata.features.${feature} or {};
    in lib.elem systemConfig.systemType (meta.systemTypes or [])
  ) uniqueFeatures;

  # Check conflicts
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

  # Resolve dependencies
  resolveDependencies = features:
    let
      allDeps = lib.flatten (map (f:
        let meta = metadata.features.${f} or {};
        in meta.dependencies or []
      ) features);
      # Add dependencies that are not yet in the list
      missingDeps = lib.filter (d: !lib.elem d features) allDeps;
    in
      if missingDeps == [] then features
      else resolveDependencies (features ++ missingDeps);

  # Final feature list
  finalFeatures = checkConflicts (resolveDependencies validFeatures);

  # Load feature modules
  featureModules = map (feature:
    ./features/${feature}.nix
  ) finalFeatures;

  # Special handling for Docker: Determine which Docker feature is active
  dockerFeature = lib.findFirst (f: f == "docker" || f == "docker-rootless") null finalFeatures;
  dockerMode = getDockerMode dockerFeature;

  # Docker modules (handled separately, as it needs systemConfig-based logic)
  dockerModule = if dockerMode == false then []
    else if dockerMode == "root" then [ ./features/docker.nix ]
    else [ ./features/docker-rootless.nix ];

in {
  imports = 
    # Base for systemType
    [ (basePackages.${systemConfig.systemType} or (throw "Unknown system type: ${systemConfig.systemType}")) ]
    # Feature modules (without Docker, as it's handled separately)
    ++ (lib.filter (m: !lib.hasSuffix "/docker.nix" (toString m) && !lib.hasSuffix "/docker-rootless.nix" (toString m)) featureModules)
    # Docker modules added separately
    ++ dockerModule;
}
