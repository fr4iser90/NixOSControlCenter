{ lib, ... }:

{
  options.systemConfig.modules.security.ssh-manager = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "2.0";
      internal = true;
      description = "Module config shape version (module-migration tracks this)";
    };

    _dependencies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "system-checks" "command-center" ];
      internal = true;
    };

    _conflicts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      internal = true;
    };

    # enable = this host as SSH server (sshd + unlock + lockdown)
    enable = lib.mkEnableOption ''
      SSH server on this host: OpenSSH daemon, unlock tools
      (temp-open / grant-access / status / lockdown). Daemon stays
      enabled across rebuilds while this is true.
    '';

    passwordAuthentication = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Declarative PasswordAuthentication. Default true for VPS bootstrap.
        After pubkey works: ncc ssh lockdown (or set false manually).
      '';
    };

    permitRootLogin = lib.mkOption {
      type = lib.types.enum [ "yes" "no" "prohibit-password" "forced-commands-only" ];
      default = "yes";
      description = ''
        Root SSH login. Default "yes" for VPS bootstrap; lockdown sets "no".
      '';
    };

    workflow = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Request/approve/list/monitor/notifications (optional).";
      };
    };

    # Optional outbound client (former ssh-manager)
    client = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "SSH client connection manager (ncc ssh client). Default off.";
      };

      credentialsFile = lib.mkOption {
        type = lib.types.str;
        default = ".creds";
        description = "Credentials file relative to home (server_ip=username).";
      };

      keyType = lib.mkOption {
        type = lib.types.str;
        default = "rsa";
        description = "SSH key type to generate";
      };

      keyBits = lib.mkOption {
        type = lib.types.int;
        default = 4096;
        description = "SSH key bits";
      };

      fzf = {
        theme = {
          prompt = lib.mkOption {
            type = lib.types.str;
            default = "→ ";
          };
          pointer = lib.mkOption {
            type = lib.types.str;
            default = "▶";
          };
          marker = lib.mkOption {
            type = lib.types.str;
            default = "✓";
          };
          header = lib.mkOption {
            type = lib.types.str;
            default = "bold";
          };
        };
        keybindings = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {
            "ctrl-x" = "delete";
            "ctrl-e" = "edit";
            "ctrl-n" = "new";
            "enter" = "connect";
          };
        };
        preview = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          position = lib.mkOption {
            type = lib.types.str;
            default = "right:40%";
          };
        };
      };
    };

    banner = lib.mkOption {
      type = lib.types.str;
      default = ''
        ===============================================
        NCC SSH server

        Bootstrap: password auth may still be on (safe default).
        After keys work: sudo ncc ssh lockdown
        Temporary reopen: ncc ssh temp-open USER | grant-access USER
        ===============================================
      '';
      description = "SSH login banner text";
    };
  };
}
