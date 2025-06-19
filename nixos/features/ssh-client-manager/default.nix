{ config, lib, pkgs, systemConfig, ... }:

# SSH Client Manager Default Module
# This is the main entry point that imports all SSH client manager components

{
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

}