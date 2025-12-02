{ config, lib, pkgs, systemConfig, ... }:

let
  # Load metadata
  metadata = import ./metadata.nix;
  
  # Load base packages
  basePackages = {
    desktop = import ./base/desktop.nix;
    server = import ./base/server.nix;
    homelab = import ./base/homelab.nix;
  };

  # Docker-Mode-Logik: Bestimme ob root oder rootless Docker verwendet werden soll
  #
  # Default-Strategie:
  # - Default: "rootless" (sicherer, reicht für die meisten Fälle)
  # - AI-Workspace aktiv → automatisch "root" (OCI-Containers brauchen root)
  # - User kann explizit "root" wählen für Swarm
  #
  # Unterstützte Werte:
  # - false → kein Docker
  # - true → Backward-Kompatibilität → "rootless" (Default)
  # - "root" → root Docker (für Swarm/OCI-Containers)
  # - "rootless" → rootless Docker (sicherer, Default)
  getDockerMode = dockerFeature:
    let
      # AI-Workspace braucht root (OCI-Containers)
      needsRoot = systemConfig.features.ai-workspace or false;
      
      # Wenn "docker" Feature aktiv → root
      # Wenn "docker-rootless" Feature aktiv → rootless
      dockerValue = if dockerFeature == "docker" then "root"
                    else if dockerFeature == "docker-rootless" then "rootless"
                    else false;
    in
      if dockerValue == false then false
      else if needsRoot then "root"  # AI-Workspace überschreibt zu root
      else dockerValue;  # User-Auswahl oder Default "rootless"

  # Lade Preset wenn gesetzt
  presetConfig = if systemConfig.preset or null != null then
    import (./presets + "/${systemConfig.preset}.nix")
  else null;

  # Kombiniere Preset-Features + zusätzliche Package Modules + direkte Package Modules
  allFeatures = 
    (presetConfig.features or [])
    ++ (systemConfig.additionalPackageModules or [])
    ++ (systemConfig.packageModules or []);

  # Entferne Duplikate
  uniqueFeatures = lib.unique allFeatures;

  # Filtere Features nach systemType
  validFeatures = lib.filter (feature:
    let meta = metadata.features.${feature} or {};
    in lib.elem systemConfig.systemType (meta.systemTypes or [])
  ) uniqueFeatures;

  # Prüfe Conflicts
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

  # Auflösen von Dependencies
  resolveDependencies = features:
    let
      allDeps = lib.flatten (map (f:
        let meta = metadata.features.${f} or {};
        in meta.dependencies or []
      ) features);
      # Füge Dependencies hinzu, die noch nicht in der Liste sind
      missingDeps = lib.filter (d: !lib.elem d features) allDeps;
    in
      if missingDeps == [] then features
      else resolveDependencies (features ++ missingDeps);

  # Finale Feature-Liste
  finalFeatures = checkConflicts (resolveDependencies validFeatures);

  # Lade Feature-Module
  featureModules = map (feature:
    ./features/${feature}.nix
  ) finalFeatures;

  # Spezielle Behandlung für Docker: Bestimme welches Docker-Feature aktiv ist
  dockerFeature = lib.findFirst (f: f == "docker" || f == "docker-rootless") null finalFeatures;
  dockerMode = getDockerMode dockerFeature;

  # Docker-Module (wird separat behandelt, da es systemConfig-basierte Logik braucht)
  dockerModule = if dockerMode == false then []
    else if dockerMode == "root" then [ ./features/docker.nix ]
    else [ ./features/docker-rootless.nix ];

in {
  imports = 
    # Base für systemType
    [ (basePackages.${systemConfig.systemType} or (throw "Unknown system type: ${systemConfig.systemType}")) ]
    # Feature-Module (ohne Docker, da separat behandelt)
    ++ (lib.filter (m: !lib.hasSuffix "/docker.nix" (toString m) && !lib.hasSuffix "/docker-rootless.nix" (toString m)) featureModules)
    # Docker-Module separat hinzufügen
    ++ dockerModule;
}
