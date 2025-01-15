{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.services.pihole;
in {
  options.services.pihole = {
    enable = mkEnableOption "Enable Pi-hole DNS service";
  };

  config = {
    # Ensure required directories exist
    systemd.tmpfiles.rules = [
      "d /var/lib/pihole 0755 root root -"
      "d /var/lib/pihole/etc-pihole 0755 root root -"
      "d /var/lib/pihole/etc-dnsmasq.d 0755 root root -"
    ];

    virtualisation.oci-containers.containers.pihole = {
      image = "pihole/pihole:latest";
      autoStart = true;
      ports = [
        "53:53/tcp"
        "53:53/udp"
        "853:853"
      ];
      volumes = [
        "/var/lib/pihole/etc-pihole:/etc/pihole"
        "/var/lib/pihole/etc-dnsmasq.d:/etc/dnsmasq.d"
      ];
      environment = {
        WEBPASSWORD = cfg.security.secrets.webpassword.source;
        TZ = config.time.timeZone;
        VIRTUAL_HOST = "${cfg.subdomain}.${systemConfig.domain}";
      };
      extraOptions = [
        "--network=proxy"
        "--label=traefik.enable=true"
        "--label=traefik.docker.network=proxy"
        "--label=traefik.http.routers.pihole.entrypoints=websecure"
        "--label=traefik.http.routers.pihole.rule=Host(`${cfg.subdomain}.${systemConfig.domain}`)"
        "--label=traefik.http.routers.pihole.tls=true"
        "--label=traefik.http.routers.pihole-secure.service=pihole"
        "--label=traefik.http.routers.pihole.tls.certresolver=http_resolver"
        "--label=traefik.http.routers.pihole.middlewares=default@file,admin-whitelist@file,rate-limit@docker"
        "--label=traefik.http.services.pihole.loadbalancer.server.port=80"
      ];
    };

    systemd.services.pihole-healthcheck = {
      description = "Pi-hole DNS server health check";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.curl}/bin/curl -sf http://localhost/admin || exit 1";
      };
    };

    systemd.timers.pihole-healthcheck = {
      description = "Pi-hole DNS server health check timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnUnitActiveSec = "30s";
        Unit = "pihole-healthcheck.service";
      };
    };

  };
}
