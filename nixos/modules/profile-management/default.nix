{ config, lib, pkgs, systemConfig, ... }:

let
  # Hilfsfunktionen
  findModules = dir:
    let
      files = builtins.readDir dir;
      nixFiles = lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".nix" n) files;
      modules = lib.mapAttrs (n: _: import (dir + "/${n}")) nixFiles;
    in modules;

  # Basis-Profile laden
  baseProfiles = {
    desktop = import ./profiles/base/desktop.nix;
    server = import ./profiles/base/server.nix;
    homelab = import ./profiles/custom/homelab.nix;
  };

  # Aktive Module aus systemConfig extrahieren
  activeModules = lib.flatten (lib.mapAttrsToList (moduleName: moduleConfig:
    # Für jedes Modul
    let
      # Basis-Modul laden wenn es existiert
      baseModule = if builtins.pathExists ./profiles/modules/${moduleName}/default.nix
                  then [ ./profiles/modules/${moduleName}/default.nix ]
                  else [];
      
      # Sub-Module laden die auf true gesetzt sind
      subModules = lib.mapAttrsToList (subName: enabled:
        if enabled 
        then ./profiles/modules/${moduleName}/${subName}.nix
        else null
      ) moduleConfig;
    in
    # Null-Werte filtern und Listen zusammenführen
    baseModule ++ (builtins.filter (x: x != null) subModules)
  ) systemConfig.profileModules);

in {
  imports = 
    # Basis-Profil laden
    [ (baseProfiles.${systemConfig.systemType} or (throw "Unknown system type: ${systemConfig.systemType}")) ] 
    # Aktive Module laden
    ++ activeModules;
}