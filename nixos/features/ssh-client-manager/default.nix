{ config, lib, pkgs, systemConfig, ... }:

with lib;

# SSH Client Manager Default Module
# This is the main entry point that imports all SSH client manager components

let
  cfg = config.features.ssh-client-manager;
in {
  # Import all SSH client manager modules
  imports = [
    ./options.nix        # Configuration options and defaults
    ./init.nix          # Initialization and setup scripts
    ./main.nix          # Main interactive script and command registration
    ./connection-preview.nix  # FZF preview functionality
    ./ssh-key-utils.nix      # SSH key management utilities
    ./ssh-server-utils.nix   # Server connection utilities
    ./connection-handler.nix # Centralized connection handler
  ];

  config = mkMerge [
    {
      features.ssh-client-manager.enable = mkDefault (systemConfig.features.ssh-client-manager or false);
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