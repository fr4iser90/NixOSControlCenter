{ lib, ... }:

let
  featureVersion = "1.0";
in {
  # SSH Client Manager Options
  # This module defines all configuration options for the SSH client manager
  options.features.ssh-client-manager = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = featureVersion;
      internal = true;
      description = "Feature version";
    };

    enable = lib.mkEnableOption "SSH client manager";

    # Internal option for SSH key utilities (set by ssh-key-utils.nix)
    sshClientManagerKeyUtils = lib.mkOption {
      type = lib.types.str;
      internal = true;
      description = "SSH-Key utility functions";
    };

    # Internal option for SSH server utilities (set by ssh-server-utils.nix)
    sshClientManagerServerUtils = lib.mkOption {
      type = lib.types.str;
      internal = true;
      description = "SSH-Server entry utility functions";
    };

    # Internal option for the centralized connection handler (set by connection-handler.nix)
    sshConnectionHandler = lib.mkOption {
      type = lib.types.str;
      internal = true;
      description = "Centralized SSH connection handler functions";
    };

    # Internal option for the main SSH client manager script (set by main.nix)
    sshClientManagerScript = lib.mkOption {
      type = lib.types.str;
      internal = true;
      description = "SSH-Server entry utility functions";
    };

    # Path to the credentials file relative to user's home directory
    # This file stores server entries in format: server_ip=username
    credentialsFile = lib.mkOption {
      type = lib.types.str;
      default = ".creds";
      description = "Path to the credentials file relative to user's home";
    };

    # SSH key type to generate (rsa, ed25519, ecdsa, etc.)
    keyType = lib.mkOption {
      type = lib.types.str;
      default = "rsa";
      description = "SSH key type to generate";
    };

    # Number of bits for SSH key generation
    keyBits = lib.mkOption {
      type = lib.types.int;
      default = 4096;
      description = "Number of bits for SSH key";
    };

    # FZF (fuzzy finder) configuration for interactive server selection
    fzf = {
      # Theme configuration for FZF appearance
      theme = {
        # Prompt symbol shown in FZF interface
        prompt = lib.mkOption {
          type = lib.types.str;
          default = "→ ";
          description = "FZF prompt symbol";
        };

        # Pointer symbol for current selection
        pointer = lib.mkOption {
          type = lib.types.str;
          default = "▶";
          description = "FZF pointer symbol";
        };

        # Marker symbol for selected items
        marker = lib.mkOption {
          type = lib.types.str;
          default = "✓";
          description = "FZF marker symbol";
        };

        # Header style for FZF interface
        header = lib.mkOption {
          type = lib.types.str;
          default = "bold";
          description = "FZF header style";
        };
      };

      # Keybinding configuration for FZF actions
      keybindings = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {
          "ctrl-x" = "delete";  # Delete server
          "ctrl-e" = "edit";    # Edit server
          "ctrl-n" = "new";     # Add new server
          "enter" = "connect";  # Connect to server
        };
        description = "FZF keybinding configuration";
      };

      # Preview window configuration for FZF
      preview = {
        # Enable/disable preview window in FZF
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable preview window in FZF";
        };

        # Position and size of the preview window
        position = lib.mkOption {
          type = lib.types.str;
          default = "right:40%";
          description = "Position and size of the preview window";
        };
      };
    };

    # Script for the FZF preview feature in the SSH Manager
    # This script shows detailed information about selected servers
    connectionPreviewScript = lib.mkOption {
      type = lib.types.package;
      description = "Script for the FZF preview feature in the SSH Manager.";
    };
  };
}
