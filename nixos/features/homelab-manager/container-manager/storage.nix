{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.homelab.storage;
in {
  options.homelab.storage = {
    enable = mkEnableOption "Enable homelab storage management";

    baseDir = mkOption {
      type = types.path;
      default = "/var/lib/homelab";
      description = "Base directory for all homelab data";
    };

    volumes = mkOption {
      type = types.attrsOf config.homelab.types.volumeOptions;
      default = {};
      description = "Volume configurations";
    };

    # Hilfsfunktionen
    createVolume = mkOption {
      type = types.functionTo types.attrs;
      default = name: settings: {
        inherit name;
        path = "${cfg.baseDir}/${name}";
        mode = settings.mode or "0755";
        user = settings.user or "root";
        group = settings.group or "root";
        backup = settings.backup or false;
        labels = settings.labels or {};
      };
      description = "Helper function to create volume configurations";
    };

    getVolumePath = mkOption {
      type = types.functionTo types.str;
      default = name: "${cfg.baseDir}/${name}";
      description = "Get full path for a volume";
    };
  };

  config = mkIf cfg.enable {
    # Basis-Verzeichnisse erstellen
    systemd.services.homelab-storage-init = {
      description = "Initialize homelab storage directories";
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
        in pkgs.writeScript "init-homelab-storage" ''
          #!${pkgs.bash}/bin/bash
          mkdir -p ${cfg.baseDir}
          ${createDirs}
        '';
      };
    };

    # Backup-Service für Volumes mit backup = true
    systemd.services.homelab-volume-backup = mkIf (any (v: v.backup) (attrValues cfg.volumes)) {
      description = "Backup homelab volumes";
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
        in pkgs.writeScript "backup-homelab-volumes" ''
          #!${pkgs.bash}/bin/bash
          mkdir -p ${cfg.baseDir}/backups
          ${backupDirs}
        '';
      };
    };

    # Standard-Volumes
    homelab.storage.volumes = {
      # Hier könnten Standard-Volumes definiert werden
    };
  };
}