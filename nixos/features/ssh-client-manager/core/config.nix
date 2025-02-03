{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ssh-manager;
in {
  options.services.ssh-manager = {
    utils = mkOption {
      type = types.str;
      internal = true;
      description = "SSH manager utility functions";
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
  };

  config = {
    environment.systemPackages = [ 
      pkgs.fzf
      pkgs.openssh
    ];
  };
}
