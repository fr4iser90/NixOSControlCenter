{ config, lib, pkgs, ... }:

with lib;

let
  volumeOptions = types.submodule {
    options = {
      path = mkOption {
        type = types.path;
        description = "Absolute path to the volume";
      };
      user = mkOption {
        type = types.str;
        default = "podman";
        description = "Owner user of the volume";
      };
      group = mkOption {
        type = types.str;
        default = "podman";
        description = "Owner group of the volume";
      };
      mode = mkOption {
        type = types.str;
        default = "755";
        description = "Permissions mode for the volume";
      };
      backup = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable daily backups for this volume";
      };
      initData = mkOption {
        type = types.nullOr types.path; # or types.anything if you do a derivation
        default = null;
        description = ''
          Path (in the Nix store) containing initial data for this volume.
          If this volume directory is empty, it will be populated from here.
        '';
      };
    };
  };

  cfg = config.storage;
  
  # Script to initialize volumes
  generateInitScript = let
    createAndCopy = concatStringsSep "\n" (
      mapAttrsToList (name: volume: ''
        # Ensure directory
        mkdir -p ${volume.path}
        chown ${volume.user}:${volume.group} ${volume.path}
        chmod ${volume.mode} ${volume.path}

        # Check if .initDataCopied exists
        if [ ! -f ${volume.path}/.initDataCopied ]; then
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] Initializing volume ${name} at ${volume.path}"

          ${if volume.initData != null then
            ''
              # Ensure source directory exists
              if [ -d "${volume.initData}" ]; then
                cp -r ${volume.initData}/* ${volume.path}/ || {
                  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed to copy data for ${name}";
                  exit 1;
                }

                # Set ownership and permissions
                chown -R ${volume.user}:${volume.group} ${volume.path}
                chmod -R ${volume.mode} ${volume.path}

                # Mark as initialized
                touch ${volume.path}/.initDataCopied
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Successfully initialized volume ${name}"
              else
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] initData path ${volume.initData} does not exist for volume ${name}"
              fi
            '' else
            ''
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] No initData defined for volume ${name}, skipping initialization"
            ''}
        else
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] Volume ${name} already initialized"
        fi
      '') cfg.volumes
    );
  in pkgs.writeScriptBin "init-container-volumes" ''
    #!/bin/bash
    set -euo pipefail

    # Logging setup
    LOG_DIR="/var/log/container-manager"
    LOG_FILE="$LOG_DIR/volume-init.log"
    mkdir -p "$LOG_DIR"
    exec > >(tee -a "$LOG_FILE") 2>&1

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting volume initialization"

    # Continue with volume initialization
    ${createAndCopy}

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Volume initialization complete"
  '';


in {
  options.podmanStorage = {
    enable = mkEnableOption "Enable Podman storage management";

    driver = mkOption {
      type = types.str;
      default = "overlay";
      description = "Storage driver to use";
    };

    graphroot = mkOption {
      type = types.path;
      default = "/var/lib/containers/storage";
      description = "Root directory for storage";
    };

    runroot = mkOption {
      type = types.path;
      default = "/run/user/$(id -u)/podman";
      description = "Runtime directory for storage";
    };

    mountProgram = mkOption {
      type = types.path;
      default = "${pkgs.fuse-overlayfs}/bin/fuse-overlayfs";
      description = "Path to mount program for overlay storage";
    };
  };

  options.storage = {
    enable = mkEnableOption "Enable storage management";

    baseDir = mkOption {
      type = types.path;
      default = "/var/lib/containers";
      description = "Base directory for all container data";
    };

    volumes = mkOption {
      type = types.attrsOf volumeOptions;
      default = {};
      description = "Volume configurations";
    };

    getVolumePath = mkOption {
      type = types.functionTo types.path;
      default = volumeName: 
        assert hasAttr volumeName config.storage.volumes;
        config.storage.volumes.${volumeName}.path;
      description = "Function to get volume path by name";
    };
  };

  config = {

    # Helper function to get volume paths
    storage.getVolumePath = volumeName: 
      assert hasAttr volumeName cfg.volumes;
      cfg.volumes.${volumeName}.path;

    # Middleware service definition
    systemd.services.init-container-volumes = {
      description = "Container Volume Initialization Middleware";
      before = [ "docker.service" "podman.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${generateInitScript}/bin/init-container-volumes";
        RemainAfterExit = true;

        User = "root";
        Group = "root";
      };
    };

    # Provide initialization script as a binary in PATH
    environment.systemPackages = [ 
      generateInitScript

      ];

    # Backup-Service für Volumes mit backup = true
    systemd.services.volume-backup = mkIf (any (v: v.backup) (attrValues cfg.volumes)) {
      description = "Backup container volumes";
      startAt = "daily";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = let
          backupDirs = concatStringsSep "\n" (mapAttrsToList (name: volume: 
            optionalString volume.backup ''
              mkdir -p ${cfg.baseDir}/backups/${name}
              tar czf ${cfg.baseDir}/backups/${name}/backup-$(date +%Y%m%d).tar.gz -C ${volume.path} .
              # Alte Backups aufräumen (behalte die letzten 7)
              ls -t ${cfg.baseDir}/backups/${name}/backup-*.tar.gz | tail -n +8 | xargs rm -f
            ''
          ) cfg.volumes);
        in pkgs.writeScript "backup-container-volumes" ''
          #!${pkgs.bash}/bin/bash
          mkdir -p ${cfg.baseDir}/backups
          ${backupDirs}
        '';
      };
    };
  };
}
