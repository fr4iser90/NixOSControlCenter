{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

with lib;

# SSH Client Manager Default Module
# This is the main entry point that imports all SSH client manager components

let
  # Use the new generic module system
  cfg = getModuleConfig "ssh-client-manager";
in {
  _module.metadata = {
    role = "optional";
    name = "ssh-client-manager";
    description = "SSH client configuration and key management";
    category = "security";
    subcategory = "ssh";
    stability = "stable";
  };

  # Import all SSH client manager modules
  imports = if cfg.enable or false then [
    ./options.nix        # Configuration options and defaults
    ./commands.nix       # Command registration for ncc
    ./config.nix         # Configuration and activation scripts
    ./init.nix          # Initialization and setup scripts
    ./main.nix          # Main interactive script
    ./connection-preview.nix  # FZF preview functionality
    ./ssh-key-utils.nix      # SSH key management utilities
    ./ssh-server-utils.nix   # Server connection utilities
    ./connection-handler.nix # Centralized connection handler
  ] else [];

  config = mkMerge [
    {
      # Use the new module config path
      modules.security.ssh-client-manager.enable = mkDefault (cfg.enable or false);
    }
    (mkIf cfg.enable {
      # Add required packages to system packages
      environment.systemPackages = [ 
        pkgs.fzf      # Fuzzy finder for interactive selection
        pkgs.openssh  # SSH client and server tools
      ];
    })
  ];
}