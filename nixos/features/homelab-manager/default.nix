{ config, lib, pkgs, systemConfig, ... }:

let
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

in {
  imports = if hasDockerUser then [
    ./homelab-create.nix
    ./homelab-fetch.nix
    # ./homelab-update.nix
    # ./homelab-delete.nix
    # ./homelab-status.nix
  ] else [];
}
