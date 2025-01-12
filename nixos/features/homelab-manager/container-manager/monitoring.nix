{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.homelab.monitoring;
in {
  options.homelab.monitoring = {
    enable = mkEnableOption "Enable homelab monitoring";

    # Basis-Monitoring
    healthchecks = {
      enable = mkEnableOption "Enable container health monitoring";
      
      options = mkOption {
        type = types.attrsOf config.homelab.types.monitoringTypes.healthcheckOptions;
        default = {};
        description = "Per-container health check configurations";
      };
    };

    logging = {
      enable = mkEnableOption "Enable basic logging";
      
      options = mkOption {
        type = types.attrsOf config.homelab.types.monitoringTypes.loggingOptions;
        default = {};
        description = "Per-container logging configurations";
      };
    };
    # Hilfsfunktionen
    getContainerHealth = mkOption {
      type = types.functionTo types.str;
      default = name: ''${pkgs.podman}/bin/podman inspect --format '{{.State.Health.Status}}' "${name}" 2>/dev/null || echo "unknown"'';
      description = "Get health status of a container";
    };

    getContainerLogs = mkOption {
      type = types.functionTo types.str;
      default = name: ''${pkgs.podman}/bin/podman logs --tail=100 "${name}"'';
      description = "Get logs of a container";
    };
  };

  config = mkIf cfg.enable {
    # Basis-Monitoring Service
    systemd.services.homelab-monitor = mkIf cfg.healthchecks.enable {
      description = "Basic homelab monitoring";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeScript "check-containers" ''
          #!${pkgs.bash}/bin/bash
          echo "Container Health Status:" > /var/lib/homelab/status.txt
          ${pkgs.podman}/bin/podman ps -a --format "{{.Names}}" | while read container; do
            health=$(${cfg.getContainerHealth "$container"})
            echo "$container: $health" >> /var/lib/homelab/status.txt
          done
        '';
      };
    };

    # Log Rotation
    systemd.services.homelab-log-cleanup = mkIf cfg.logging.enable {
      description = "Cleanup old homelab logs";
      startAt = "daily";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeScript "cleanup-logs" ''
          #!${pkgs.bash}/bin/bash
          find ${cfg.logging.logDir} -type f -mtime +${cfg.logging.retention} -delete
        '';
      };
    };

    # Verzeichnisse erstellen
    systemd.tmpfiles.rules = [
      "d ${cfg.logging.logDir} 0750 root root -"
    ];
  };
}