{ config, lib, pkgs, systemConfig, moduleConfig, getModuleConfigFromPath, ... }:

let
  # Generic: Use getModuleConfigFromPath to get config with defaults from options.nix
  cfg = getModuleConfigFromPath moduleConfig.configPath;
  configHelpers = import ../../core/management/module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Default SSH config
  defaultConfig = ''
    # SSH Client Manager Configuration
    # This file contains SSH connection configurations

    {
      # Default SSH connections
      connections = {
        # Example connection - modify as needed
        # "server1" = {
        #   host = "192.168.1.100";
        #   user = "user";
        #   port = 22;
        #   identityFile = "~/.ssh/id_rsa";
        # };

        # Add your SSH connections here
      };

      # Default settings
      settings = {
        terminal = "kitty";  # Default terminal for SSH sessions
        editor = "nano";     # Default editor for config files
      };
    }
  '';
in
  lib.mkMerge [
    (lib.mkIf (cfg.enable or false) (
      (configHelpers.createModuleConfig {
        moduleName = "ssh-client-manager";
        defaultConfig = defaultConfig;
      }) // {
        # Enable module by default if config has it
        ${moduleConfig.configPath}.enable = lib.mkDefault (cfg.enable or false);
      }
    ))
    # Implementation is handled in default.nix
  ]
