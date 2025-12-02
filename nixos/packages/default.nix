{ config, lib, pkgs, systemConfig, ... }:

let
  # Helper functions
  findModules = dir:
    let
      files = builtins.readDir dir;
      nixFiles = lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".nix" n) files;
      modules = lib.mapAttrs (n: _: import (dir + "/${n}")) nixFiles;
    in modules;

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
  getDockerMode = dockerConfig:
    let
      # AI-Workspace braucht root (OCI-Containers)
      needsRoot = systemConfig.features.ai-workspace or false;
      
      # Normalisiere docker Config
      dockerValue = if dockerConfig == true then "rootless"  # Backward-Kompatibilität
                    else if dockerConfig == false then false
                    else dockerConfig;  # "root" oder "rootless"
    in
      if dockerValue == false then false
      else if needsRoot then "root"  # AI-Workspace überschreibt zu root
      else dockerValue;  # User-Auswahl oder Default "rootless"

  # AUTOMATISCHE DOCKER-AKTIVIERUNG basierend auf systemType
  # Docker wird automatisch aktiviert, außer wenn explizit deaktiviert
  # - Desktop → rootless Docker (sicherer)
  # - Homelab → rootless Docker (sicherer, reicht für Single-Server)
  # - Server → rootless Docker (sicherer)
  # - AI-Workspace aktiv → root Docker (OCI-Containers brauchen root)
  # - Docker Swarm → root Docker (Swarm braucht root, rootless Swarm ist experimentell)
  # - Explizit docker = false → kein Docker
  # - Explizit docker = "root" → root Docker (für Swarm/OCI-Containers)
  
  # Sammle alle Docker-Configs aus allen Modulen
  allDockerConfigs = lib.mapAttrsToList (moduleName: moduleConfig:
    moduleConfig.docker or null
  ) systemConfig.packageModules;
  
  # Finde explizite Docker-Config (wenn gesetzt)
  explicitDockerConfig = lib.findFirst (x: x != null) null allDockerConfigs;
  
  # Bestimme ob Docker automatisch aktiviert werden soll
  shouldAutoEnableDocker = 
    # Wenn explizit false → kein Docker
    if explicitDockerConfig == false then false
    # Wenn explizit gesetzt → verwende das
    else if explicitDockerConfig != null then explicitDockerConfig
    # Sonst: Automatisch aktivieren basierend auf systemType
    else "rootless";  # Default: rootless für alle systemTypes

  # Extract active modules from systemConfig
  activeModules = lib.flatten (lib.mapAttrsToList (moduleName: moduleConfig:
    let
      # ALWAYS load the base module if any sub-module is active
      baseModule = if (lib.any (x: x == true || (lib.isString x && x != "")) (lib.attrValues moduleConfig))
                  then [ ./modules/${moduleName}/default.nix ]
                  else [];
      
      # Load sub-modules - spezielle Behandlung für Docker
      subModules = lib.mapAttrsToList (subName: enabled:
        if subName == "docker" then
          # Docker: Verwende automatische Aktivierung wenn nicht explizit gesetzt
          let dockerValue = if enabled == null then shouldAutoEnableDocker else enabled;
              dockerMode = getDockerMode dockerValue;
          in if dockerMode == false then null
             else if dockerMode == "root" then ./modules/server/${subName}.nix
             else ./modules/server/${subName}-rootless.nix
        else if enabled == true || (lib.isString enabled && enabled != "") then
          ./modules/${moduleName}/${subName}.nix
        else null
      ) moduleConfig;
    in
    # Filter null values and merge lists
    baseModule ++ (builtins.filter (x: x != null) subModules)
  ) systemConfig.packageModules);

  # Wenn Docker automatisch aktiviert werden soll, füge es zu den Imports hinzu
  dockerModule = if shouldAutoEnableDocker != false then
    let dockerMode = getDockerMode shouldAutoEnableDocker;
    in if dockerMode == "root" then [ ./modules/server/docker.nix ]
       else [ ./modules/server/docker-rootless.nix ]
    else [];

in {
  imports = 
    # Load base system package
    [ (basePackages.${systemConfig.systemType} or (throw "Unknown system type: ${systemConfig.systemType}")) ] 
    # Load active modules + their base modules
    ++ activeModules
    # Automatisch Docker aktivieren wenn gewünscht
    ++ dockerModule;
}