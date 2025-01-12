{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.homelab.security;
in {
  options.homelab.security = {
    enable = mkEnableOption "Enable homelab security management";

    users = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          uid = mkOption {
            type = types.int;
            description = "User ID";
          };
          group = mkOption {
            type = types.str;
            description = "Group";
          };
          groups = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Additional groups";
          };
          createSystemUser = mkOption {
            type = types.bool;
            default = true;
            description = "Create system user";
          };
        };
      });
      default = {};
      description = "Container users configuration";
    };

    secrets = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          source = mkOption {
            type = types.path;
            description = "Secret source";
          };
          owner = mkOption {
            type = types.str;
            description = "Owner";
          };
          group = mkOption {
            type = types.str;
            description = "Group";
          };
          mode = mkOption {
            type = types.str;
            default = "0400";
            description = "Permissions";
          };
          mountPath = mkOption {
            type = types.str;
            description = "Mount path";
          };
        };
      });
      default = {};
      description = "Secret files configuration";
    };

    secretsDir = mkOption {
      type = lib.types.path;
      default = "/var/lib/homelab/secrets";
      description = "Base directory for secrets";
    };

    # Hilfsfunktionen
    createUser = mkOption {
      type = lib.types.functionTo lib.types.attrs;
      default = name: settings: {
        inherit name;
        uid = settings.uid;
        group = settings.group;
        groups = settings.groups or [];
        createSystemUser = settings.createSystemUser or true;
      };
      description = "Helper function to create user configurations";
    };

    getUser = mkOption {
      type = lib.types.functionTo lib.types.attrs;
      default = name: cfg.users.${name} or null;
      description = "Get user configuration by name";
    };
  };

  config = mkIf cfg.enable {
    # System Users erstellen
    users = mkMerge (mapAttrsToList (name: user:
      mkIf user.createSystemUser {
        groups.${user.group} = {};
        users.${name} = {
          isSystemUser = true;
          group = user.group;
          extraGroups = user.groups;
          uid = user.uid;
          home = "/var/empty";
          createHome = false;
          shell = pkgs.shadow;
        };
      }
    ) cfg.users);

    # Secrets Management
    systemd.services.homelab-secrets = {
      description = "Setup homelab secrets";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];  # Hinzugefügt
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = let
          setupSecrets = concatStringsSep "\n" (mapAttrsToList (name: secret: ''
            mkdir -p $(dirname ${cfg.secretsDir}/${name})
            install -m ${secret.mode} ${secret.source} ${cfg.secretsDir}/${name}  # Sicherer mit install
            chown ${secret.owner}:${secret.group} ${cfg.secretsDir}/${name}
          '') cfg.secrets);
        in pkgs.writeScript "setup-homelab-secrets" ''
          #!${pkgs.bash}/bin/bash
          install -d -m 700 ${cfg.secretsDir}  # Sicherer mit install
          ${setupSecrets}
        '';
      };
    };
  };
}