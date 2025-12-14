{ config, lib, pkgs, systemConfig, ... }:

with lib;

# SSH Client Manager Default Module
# This is the main entry point that imports all SSH client manager components

let
  # 🏗️ AUTOMATIC MODULE CONFIGURATION
  # Get config helpers with automatic module framework
  configHelpersLib = import ../../core/management/module-manager/lib/config-helpers.nix {
    inherit pkgs lib;
  };

  # Automatically generate module configuration from filesystem
  moduleConfig = configHelpersLib.mkModuleConfig ./.;

  # Use auto-generated paths (no more hardcoded!)
  cfg = systemConfig.${moduleConfig.configPath};
in {
  # Import all SSH client manager modules
  imports = [
    ./options.nix        # Configuration options and defaults
    ./commands.nix       # Command registration for ncc
    ./config.nix         # Configuration and activation scripts
    ./init.nix          # Initialization and setup scripts
    ./main.nix          # Main interactive script
    ./connection-preview.nix  # FZF preview functionality
    ./ssh-key-utils.nix      # SSH key management utilities
    ./ssh-server-utils.nix   # Server connection utilities
    ./connection-handler.nix # Centralized connection handler
  ];

  # Provide module config to all submodules
  _module.args.moduleConfig = moduleConfig;

  config = mkMerge [
    {
      ${moduleConfig.configPath}.enable = mkDefault (systemConfig.${moduleConfig.configPath} or false);
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