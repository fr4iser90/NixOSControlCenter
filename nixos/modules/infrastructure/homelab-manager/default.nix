{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleMetadata, ... }:

with lib;

let
  moduleName = baseNameOf ./. ;        # "homelab-manager" - automatisch!
  cfg = getModuleConfig moduleName;
  
  # Check if Swarm is active
  isSwarmMode = (cfg.swarm or null) != null;
  
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

  # Modulname und Swarm-Konfiguration an Submodule weitergeben
  _module.args = {
    inherit moduleName;
    isSwarmMode = isSwarmMode;
  };

  imports = if cfg.enable or false then
    [
      ./options.nix
      (import ./config.nix { inherit moduleConfig; })
    ] ++ (if hasDockerUser then [
      ./handlers/homelab-create.nix
      ./handlers/homelab-fetch.nix
      # ./handlers/homelab-update.nix
      # ./handlers/homelab-delete.nix
      # ./handlers/homelab-status.nix
    ] else [])
  else [];

  config = mkMerge [
    # Generisch: enable-Flag aus Discovery-Pfad setzen
    (let
      moduleMeta = getModuleMetadata moduleName;
      enablePath = lib.splitString "." moduleMeta.enablePath;
    in
      lib.setAttrByPath enablePath (mkDefault (cfg.enable or false))
    )
    (mkIf cfg.enable {
      # Import homelab utilities config
      environment.systemPackages = (homelabUtils.config.environment.systemPackages or []);
      "${corePathsLib.getCliRegistryCommandsPath}" = (homelabUtils.config."${corePathsLib.getCliRegistryCommandsPath}" or []);
    })
  ];
}
