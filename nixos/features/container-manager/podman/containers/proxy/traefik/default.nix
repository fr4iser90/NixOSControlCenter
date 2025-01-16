{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.traefik;
  containerVars = import ./vars.nix { inherit lib config; };
  traefikConfig = import ./traefik.nix { inherit lib pkgs config containerVars; };
in {
  imports = [
    ./config.nix
    ./container.nix
    ./vars.nix
  ];

  options.services.traefik = {
    enable = mkEnableOption "Traefik reverse proxy service";
    
    containerName = mkOption {
      type = types.str;
      default = "traefik";
      description = "Name of the Traefik container";
    };

    envFile = mkOption {
      type = types.path;
      description = "Path to environment file for Traefik";
    };

    networks = mkOption {
      type = types.listOf types.str;
      default = ["crowdsec" "proxy"];
      description = "Networks to attach the container to";
    };

    volumes = mkOption {
      type = types.listOf types.str;
      default = [
        "/etc/localtime:/etc/localtime:ro"
        "/var/run/docker.sock:/var/run/docker.sock:ro"
        "/var/log/traefik:/var/log/traefik"
        "./traefik/traefik.yml:/traefik.yml:ro"
        "./traefik/acme_letsencrypt.json:/acme_letsencrypt.json"
        "./traefik/tls_letsencrypt.json:/tls_letsencrypt.json"
        "./traefik/dynamic-conf:/dynamic-conf:ro"
      ];
      description = "Volume mounts for the container";
    };

    dns = mkOption {
      type = types.listOf types.str;
      default = ["127.0.0.1" "1.1.1.1" "8.8.8.8"];
      description = "DNS servers for the container";
    };

    securityOpts = mkOption {
      type = types.listOf types.str;
      default = ["no-new-privileges=true"];
      description = "Security options for the container";
    };

    labels = mkOption {
      type = types.attrsOf types.str;
      default = {
        "traefik.docker.network" = "proxy";
        "traefik.enable" = "true";
        "traefik.http.routers.traefik.entrypoints" = "websecure";
        "traefik.http.routers.traefik.middlewares" = "default@file,traefikAuth@file,admin-whitelist@file";
        "traefik.http.routers.traefik.rule" = "Host(`traefik.${DOMAIN}`)";
        "traefik.http.routers.traefik.service" = "api@internal";
        "traefik.http.routers.traefik.tls" = "true";
        "traefik.http.routers.traefik.tls.certresolver" = "http_resolver";
      };
      description = "Docker labels for Traefik configuration";
    };
  };

  config = mkIf cfg.enable {
    services.traefik = {
      containerName = "traefik";
      envFile = "/path/to/traefik.env";
      networks = ["crowdsec" "proxy"];
      volumes = [
        "/etc/localtime:/etc/localtime:ro"
        "/var/run/docker.sock:/var/run/docker.sock:ro"
        "/var/log/traefik:/var/log/traefik"
        "./traefik/traefik.yml:/traefik.yml:ro"
        "./traefik/acme_letsencrypt.json:/acme_letsencrypt.json"
        "./traefik/tls_letsencrypt.json:/tls_letsencrypt.json"
        "./traefik/dynamic-conf:/dynamic-conf:ro"
      ];
      dns = ["127.0.0.1" "1.1.1.1" "8.8.8.8"];
      securityOpts = ["no-new-privileges=true"];
    };

    # Health check configuration
    services.traefik.healthCheck = {
      test = ["CMD" "traefik" "healthcheck" "--ping"];
      interval = "10s";
      timeout = "1s";
      retries = 3;
      startPeriod = "10s";
    };

    # Container image configuration
    services.traefik.image = {
      name = "traefik";
      tag = "v3.1.0";
    };

    # Network configuration
    networking.traefik = {
      enable = true;
      ipv4Address = "172.40.255.254";
      subnet = "172.40.0.0/16";
    };
  };
}
