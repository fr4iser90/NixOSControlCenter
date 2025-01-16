{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.security;
in {
  options.security = {
    enable = mkEnableOption "Enable security management";

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
      default = "/var/lib/secrets";
      description = "Base directory for secrets";
    };
  };

  config = {
    # Create groups first
    users.groups = mkMerge (mapAttrsToList (name: user: {
      ${user.group} = {
        gid = user.uid;
      };
    }) cfg.users);

    # Create users with proper group dependencies
    users.users = mkMerge (mapAttrsToList (name: user:
      mkIf user.createSystemUser {
        ${name} = {
          isSystemUser = true;
          group = user.group;
          extraGroups = user.groups ++ [ "podman" ];
          uid = user.uid;
          home = "/var/empty";
          createHome = false;
          shell = pkgs.shadow;
        };
      }
    ) cfg.users);

    # Validate that required groups exist
    assertions = mapAttrsToList (name: user: {
      assertion = hasAttr user.group config.users.groups;
      message = "Group ${user.group} must be defined for user ${name}";
    }) cfg.users;



    # Secrets Management
    systemd.services.secrets-setup = {
      description = "Setup secrets";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = let
          setupSecrets = concatStringsSep "\n" (mapAttrsToList (name: secret: ''
            mkdir -p $(dirname ${cfg.secretsDir}/${name})
            install -m ${secret.mode} ${secret.source} ${cfg.secretsDir}/${name}
            chown ${secret.owner}:${secret.group} ${cfg.secretsDir}/${name}
          '') cfg.secrets);
        in pkgs.writeScript "setup-secrets" ''
          #!${pkgs.bash}/bin/bash
          install -d -m 700 ${cfg.secretsDir}
          ${setupSecrets}
        '';
      };
    };
  };
}
