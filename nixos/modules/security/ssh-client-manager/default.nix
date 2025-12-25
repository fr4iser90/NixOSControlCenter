{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

with lib;

# SSH Client Manager Default Module
# This is the main entry point that imports all SSH client manager components

let
  # CONVENTION OVER CONFIGURATION - Vollständig dynamisch aus Dateisystem
  moduleName = baseNameOf ./. ;        # "ssh-client-manager" - automatisch!
  # Use the new generic module system
  cfg = getModuleConfig moduleName;
in {
  _module.metadata = {
    role = "optional";
    name = moduleName;
    description = "SSH client configuration and key management";
    category = "security";
    subcategory = "ssh";
    version = "1.0.0";
  };

  # Modulname und Config an Submodule weitergeben
  _module.args = {
    inherit moduleName;
    sshClientCfg = cfg;
  };

  # Import all SSH client manager modules - MODULE_TEMPLATE konform
  imports = if cfg.enable or false then [
    ./options.nix                    # Configuration options and defaults
    ./commands.nix                   # Command registration for ncc
    ./config.nix                     # System configuration
    ./handlers/ssh-client-handler.nix    # Business logic orchestration
    ./scripts/ssh-client-manager.nix     # Executable script
    ./lib/ssh-key-utils.nix             # SSH key utilities
    ./lib/ssh-server-utils.nix          # Server connection utilities
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