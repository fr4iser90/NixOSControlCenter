{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.features.infrastructure.homelab;
  
  # Check if Swarm is active
  isSwarmMode = (systemConfig.homelab.swarm or null) != null;
  
  # Find virtualization users (preferred)
  virtUsers = lib.filterAttrs 
    (name: user: user.role == "virtualization") 
    systemConfig.users;

  # Fallback: Find admin users if no virtualization user
  adminUsers = lib.filterAttrs 
    (name: user: user.role == "admin") 
    systemConfig.users;
  
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
  imports = [
    ./options.nix
    ./config.nix
  ] ++ (if hasDockerUser then [
    ./homelab-create.nix
    ./homelab-fetch.nix
    # ./homelab-update.nix
    # ./homelab-delete.nix
    # ./homelab-status.nix
  ] else []);

  config = mkMerge [
    {
      features.infrastructure.homelab.enable = mkDefault (systemConfig.features.infrastructure.homelab or false);
    }
    (mkIf cfg.enable {
      # Import homelab utilities config
      environment.systemPackages = (homelabUtils.config.environment.systemPackages or []);
      core.command-center.commands = (homelabUtils.config.core.command-center.commands or []);
    })
  ];
}
