{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

with lib;

let
  # Single Source: Modulname nur einmal definieren
  moduleName = "homelab-manager";
  cfg = getModuleConfig moduleName;
  
  # Check if Swarm is active
  isSwarmMode = (systemConfig.homelab.swarm or null) != null;
  
  # Find virtualization users (preferred)
  virtUsers = lib.filterAttrs
    (name: user: user.role == "virtualization")
    (getModuleConfig "user");

  # Fallback: Find admin users if no virtualization user
  adminUsers = lib.filterAttrs
    (name: user: user.role == "admin")
    (getModuleConfig "user");
  
  hasVirtUsers = (lib.length (lib.attrNames virtUsers)) > 0;
  hasAdminUsers = (lib.length (lib.attrNames adminUsers)) > 0;
  
  # Swarm requires virtualization user (not admin fallback)
  hasDockerUser = if isSwarmMode then
    hasVirtUsers  # Swarm: Only virtualization user allowed
  else
    (hasVirtUsers || hasAdminUsers);  # Single-Server: Both allowed
  
  # Fallback: Admin user if no virtualization user (only for Single-Server)
  virtUser = if hasVirtUsers then 
    (lib.head (lib.attrNames virtUsers))
  else if (hasAdminUsers && !isSwarmMode) then
    (lib.head (lib.attrNames adminUsers))  # Only if NOT Swarm
  else null;

  # Import homelab utilities
  homelabUtils = import ./lib/homelab-utils.nix { inherit config lib pkgs systemConfig; };

in {
  _module.metadata = {
    role = "optional";
    name = moduleName;
    description = "Homelab infrastructure management and orchestration";
    category = "infrastructure";
    subcategory = "homelab";
    version = "1.0.0";
  };

  # Modulname einmalig definieren und an Submodule weitergeben
  _module.args.moduleName = moduleName;

  imports = if cfg.enable or false then
    [
      ./options.nix
      ./config.nix
    ] ++ (if hasDockerUser then [
      ./homelab-create.nix
      ./homelab-fetch.nix
      # ./homelab-update.nix
      # ./homelab-delete.nix
      # ./homelab-status.nix
    ] else [])
  else [];

  config = mkMerge [
    {
      modules.infrastructure.homelab-manager.enable = mkDefault (cfg.enable or false);
    }
    (mkIf cfg.enable {
      # Import homelab utilities config
      environment.systemPackages = (homelabUtils.config.environment.systemPackages or []);
      "${corePathsLib.getCliRegistryCommandsPath}" = (homelabUtils.config."${corePathsLib.getCliRegistryCommandsPath}" or []);
    })
  ];
}
