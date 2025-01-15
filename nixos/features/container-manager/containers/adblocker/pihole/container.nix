{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.services.pihole;
  containerVars = import ./vars.nix { inherit lib config; };
  validatedVars = config.validateVars config.containerManager.vars { };
in {
  options.services.pihole = {
    enable = mkEnableOption "Enable Pi-hole DNS service";
    
    monitoring = {
      enable = mkEnableOption "Enable Pi-hole monitoring";
      interval = mkOption {
        type = types.str;
        default = "30s";
        description = "Health check interval";
      };
    };
  };

  config = {
    # Ensure required directories exist
    systemd.tmpfiles.rules = [
      "d /var/lib/pihole 0755 root root -"
      "d /var/lib/pihole/etc-pihole 0755 root root -"
      "d /var/lib/pihole/etc-dnsmasq.d 0755 root root -"
      "d /run/pihole 0755 root root -"
    ];

    virtualisation.oci-containers.containers.pihole = {
      image = "pihole/pihole:${cfg.imageTag}";
      autoStart = false;
      ports = [
        "53:53/tcp"
        "53:53/udp"
        "853:853"
      ];
      volumes = [
        "/var/lib/pihole/etc-pihole:/etc/pihole"
        "/var/lib/pihole/etc-dnsmasq.d:/etc/dnsmasq.d"
        "/run/pihole:/run/pihole"
      ];
      environmentFiles = [
        (pkgs.writeText "pihole-env" (builtins.concatStringsSep "\n" (
          mapAttrsToList (name: value: "${name}=${value}") validatedVars
        )))
      ];
      extraOptions = [
        "--network=proxy"
        "--label=traefik.enable=true"
        "--label=traefik.docker.network=proxy"
        "--label=traefik.http.routers.pihole.entrypoints=websecure"
        "--label=traefik.http.routers.pihole.rule=Host(`${cfg.subdomain}.${cfg.domain}`)"
        "--label=traefik.http.routers.pihole.tls=true"
        "--label=traefik.http.routers.pihole-secure.service=pihole"
        "--label=traefik.http.routers.pihole.tls.certresolver=http_resolver"
        "--label=traefik.http.routers.pihole.middlewares=default@file,admin-whitelist@file,rate-limit@docker"
        "--label=traefik.http.services.pihole.loadbalancer.server.port=80"
        "--restart=unless-stopped"
      ];
    };
  };
}
