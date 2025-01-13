{ config, lib, pkgs, ... }:

with lib;

let
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
      type = types.attrsOf types.volumeOptions;
      default = {};
      description = "Volume configurations";
    };
  };

  config = mkIf cfg.enable {
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