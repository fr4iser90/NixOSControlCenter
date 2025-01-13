{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.pihole;
in {
  options.services.pihole = {
    enable = mkEnableOption "Enable Pi-hole DNS service";

    subdomain = mkOption {
      type = types.str;
      default = "pihole";
      description = "Subdomain for Pi-hole web interface";
    };

    container = mkOption {
      type = types.containerOptions;
      default = {};
      description = "Container configuration for Pi-hole";
    };

    security = mkOption {
      type = types.securityTypes;
      default = {};
      description = "Security configuration for Pi-hole";
    };

    volumes = mkOption {
      type = types.attrsOf types.volumeOptions;
      default = {};
      description = "Volume configuration for Pi-hole";
    };

    monitoring = mkOption {
      type = types.monitoringTypes;
      default = {};
      description = "Monitoring configuration for Pi-hole";
    };
  };

  config = mkIf cfg.enable {
    # Security Configuration
    security.users.pihole = {
      uid = 350;
      group = "pihole";
      createSystemUser = true;
    };

    # Storage Configuration
    storage.volumes = {
      "pihole/etc-pihole" = {
        path = "${config.storage.baseDir}/pihole/etc-pihole";
        mode = "0755";
        user = "pihole";
        group = "pihole";
        backup = true;
      };
      "pihole/etc-dnsmasq.d" = {
        path = "${config.storage.baseDir}/pihole/etc-dnsmasq.d";
        mode = "0755";
        user = "pihole";
        group = "pihole";
        backup = true;
      };
    };

    # Container Configuration
    services.pihole.container = {
      enable = true;
      image = "pihole/pihole";
      version = "latest";
      user = "pihole";
      networks = [ "proxy" ];
      volumes = {
        "${config.storage.getVolumePath "pihole/etc-pihole"}" = "/etc/pihole";
        "${config.storage.getVolumePath "pihole/etc-dnsmasq.d"}" = "/etc/dnsmasq.d";
      };
      environment = {
        WEBPASSWORD = cfg.security.secrets.webpassword.source;
        PUID = toString config.security.users.pihole.uid;
        PGID = toString config.security.users.pihole.uid;
        TZ = config.time.timeZone;
        VIRTUAL_HOST = "${cfg.subdomain}.${config.domain}";
      };
      extraOptions = [
        "--ip=172.40.0.3"
        "--dns=127.0.0.1"
        "--dns=1.1.1.1"
        "-p 53:53/tcp"
        "-p 53:53/udp"
        "-p 853:853"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.docker.network" = "proxy";
        "traefik.http.routers.pihole.entrypoints" = "websecure";
        "traefik.http.routers.pihole.rule" = "Host(`${cfg.subdomain}.${config.domain}`)";
        "traefik.http.routers.pihole.tls" = "true";
        "traefik.http.routers.pihole-secure.service" = "pihole";
        "traefik.http.routers.pihole.tls.certresolver" = "http_resolver";
        "traefik.http.routers.pihole.middlewares" = "default@file,admin-whitelist@file,rate-limit@docker";
        "traefik.http.services.pihole.loadbalancer.server.port" = "80";
      };
      healthcheck = {
        command = "curl -sf http://localhost/admin || exit 1";
        interval = "30s";
        timeout = "10s";
        retries = 3;
        startPeriod = "30s";
      };
    };

    # Monitoring Configuration
    monitoring = {
      healthchecks.options.pihole = {
        enable = true;
        interval = "30s";
        command = "curl -sf http://localhost/admin || exit 1";
        retries = 3;
      };
      logging.options.pihole = {
        enable = true;
        retention = "7d";
        maxSize = "100m";
        level = "info";
      };
    };

    # Network Configuration
    networking.networks.proxy = {
      subnet = "172.40.0.0/16";
      gateway = "172.40.0.1";
      attachable = true;
    };
  };
}