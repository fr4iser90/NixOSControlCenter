{ config, lib, pkgs, systemConfig, getModuleConfig, getCurrentModuleMetadata, ... }:

with lib;

let
  moduleName = baseNameOf ./. ;        # "homelab-manager" - automatisch!
  cfg = getModuleConfig moduleName;
  # Get module metadata (generic, not hardcoded) - use getCurrentModuleMetadata for current module
  moduleConfig = getCurrentModuleMetadata ./.;
  
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
  homelabUtils = import ./lib/homelab-utils.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };

in {
  _module.args = {
    isSwarmMode = isSwarmMode;
  };

  imports = [
    ./options.nix
  ] ++ lib.optionals (cfg.enable or false) [
    ./config.nix
    ./handlers/homelab-create.nix
    ./handlers/homelab-fetch.nix
  ];

  # Put config attributes at top level, not in config =
  environment.systemPackages = mkIf (cfg.enable or false) (homelabUtils.config.environment.systemPackages or []);
}
