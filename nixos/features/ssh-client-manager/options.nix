{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ssh-client-manager;
in {
  options.services.ssh-client-manager = {
    sshClientManagerKeyUtils = mkOption {
      type = types.str;
      internal = true;
      description = "SSH-Key utility functions";
    };

    sshClientManagerServerUtils = mkOption {
      type = types.str;
      internal = true;
      description = "SSH-Server entry utility functions";
    };

    sshClientManagerScript = mkOption {
      type = types.str;
      internal = true;
      description = "SSH-Server entry utility functions";
    };

    credentialsFile = mkOption {
      type = types.str;
      default = ".creds";
      description = "Path to the credentials file relative to user's home";
    };

    keyType = mkOption {
      type = types.str;
      default = "rsa";
      description = "SSH key type to generate";
    };

    keyBits = mkOption {
      type = types.int;
      default = 4096;
      description = "Number of bits for SSH key";
    };

    fzf = {
      theme = {
        prompt = mkOption {
          type = types.str;
          default = "→ ";
          description = "FZF prompt symbol";
        };

        pointer = mkOption {
          type = types.str;
          default = "▶";
          description = "FZF pointer symbol";
        };

        marker = mkOption {
          type = types.str;
          default = "✓";
          description = "FZF marker symbol";
        };

        header = mkOption {
          type = types.str;
          default = "bold";
          description = "FZF header style";
        };
      };

      keybindings = mkOption {
        type = types.attrsOf types.str;
        default = {
          "ctrl-x" = "delete";
          "ctrl-e" = "edit";
          "ctrl-n" = "new";
          "enter" = "connect";
        };
        description = "FZF keybinding configuration";
      };

      preview = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable preview window in FZF";
        };

        position = mkOption {
          type = types.str;
          default = "right:40%";
          description = "Position and size of the preview window";
        };
      };
    };

    connectionPreviewScript = mkOption {
      type = types.package;
      description = "Script for the FZF preview feature in the SSH Manager.";
    };
  };

  config = {
    environment.systemPackages = [ 
      pkgs.fzf
      pkgs.openssh
    ];
  };
}
