{ config, lib, pkgs, systemConfig, ... }:

let
  # Helper functions
  findModules = dir:
    let
      files = builtins.readDir dir;
      nixFiles = lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".nix" n) files;
      modules = lib.mapAttrs (n: _: import (dir + "/${n}")) nixFiles;
    in modules;

  # Load base profiles
  baseProfiles = {
    desktop = import ./profiles/base/desktop.nix;
    server = import ./profiles/base/server.nix;
    homelab = import ./profiles/custom/homelab.nix;
  };

  # Extract active modules from systemConfig
  activeModules = lib.flatten (lib.mapAttrsToList (moduleName: moduleConfig:
    let
      # ALWAYS load the base module if any sub-module is active
      baseModule = if (lib.any (x: x == true) (lib.attrValues moduleConfig))
                  then [ ./profiles/modules/${moduleName}/default.nix ]
                  else [];
      
      # Load sub-modules that are set to true
      subModules = lib.mapAttrsToList (subName: enabled:
        if enabled 
        then ./profiles/modules/${moduleName}/${subName}.nix
        else null
      ) moduleConfig;
    in
    # Filter null values and merge lists
    baseModule ++ (builtins.filter (x: x != null) subModules)
  ) systemConfig.profileModules);

in {
  imports = 
    # Load base system profile
    [ (baseProfiles.${systemConfig.systemType} or (throw "Unknown system type: ${systemConfig.systemType}")) ] 
    # Load active modules + their base modules
    ++ activeModules;
}