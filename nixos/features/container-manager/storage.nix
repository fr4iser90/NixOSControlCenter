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
    };
  };

  cfg = config.storage;
in {
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

  config = mkIf cfg.enable {
    # Define Pi-hole volumes
    storage.volumes = {
      "pihole/etc-pihole" = {
        path = "${cfg.baseDir}/pihole/etc-pihole";
        user = "pihole";
        group = "pihole";
        mode = "755";
        backup = true;
      };
      "pihole/etc-dnsmasq.d" = {
        path = "${cfg.baseDir}/pihole/etc-dnsmasq.d";
        user = "pihole";
        group = "pihole";
        mode = "755";
        backup = true;
      };
    };

    # Helper function to get volume paths
    storage.getVolumePath = volumeName: 
      assert hasAttr volumeName cfg.volumes;
      cfg.volumes.${volumeName}.path;

    # Basis-Verzeichnisse erstellen
    systemd.services.container-storage-init = {
      description = "Initialize container storage directories";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = let
          createDirs = concatStringsSep "\n" (mapAttrsToList (name: volume: ''
            mkdir -p ${volume.path}
            chown ${volume.user}:${volume.group} ${volume.path}
            chmod ${volume.mode} ${volume.path}
          '') cfg.volumes);
        in pkgs.writeScript "init-container-storage" ''
          #!${pkgs.bash}/bin/bash
          mkdir -p ${cfg.baseDir}
          ${createDirs}
        '';
      };
    };

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
