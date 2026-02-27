{ lib, pkgs, getCurrentModuleMetadata, ... }:

let
  # Finde eigenes Modul aus PFAD! KEIN hardcoded Name!
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
in {
  # SSH Client Manager Options
  # This module defines all configuration options for the SSH client manager
  options.systemConfig.${configPath} = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "Module version";
    };

    # Dependencies this module has
    _dependencies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "system-checks" "command-center" ];
      internal = true;
      description = "Modules this module depends on";
    };

    # Conflicts this module has
    _conflicts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      internal = true;
      description = "Modules that conflict with this module";
    };

    enable = lib.mkEnableOption "SSH client manager";

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

  };
}
