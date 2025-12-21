{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  cfg = getModuleConfig "packages";

  # Load base packages
  basePackages = {
    desktop = import ./base/desktop.nix;
    server = import ./base/server.nix;
  };


  # Load package modules (V1 format)
  allModules = cfg.packageModules or [];

  # Determine actual Docker mode - enabled if "docker" or "docker-rootless" in packageModules
  dockerMode = let
    hasDocker = builtins.elem "docker" allModules;
    hasDockerRootless = builtins.elem "docker-rootless" allModules;
  in
    if hasDocker then "root"
    else if hasDockerRootless then "rootless"
    else null;

  # Smart Docker handling
  dockerModules = if dockerMode == "root" then [ ./modules/docker.nix ]
               else if dockerMode == "rootless" then [ ./modules/docker-rootless.nix ]
               else [];

  # Load feature modules
  moduleModules = map (mod: ./modules/${mod}.nix) allModules;

in {
  _module.metadata = {
    role = "core";   
    name = "packages";
    description = "Package management system";
    category = "base";
    subcategory = "packages";
    version = "1.0.0";
  };

  imports = [
    ./config.nix
    (basePackages.${systemConfig.core.management.system-manager.systemType} or (throw "Unknown system type: ${systemConfig.core.management.system-manager.systemType}"))
  ] ++ moduleModules ++ dockerModules;
}