{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.crowdsec;
  containerVars = import ./vars.nix { inherit lib config; };
  crowdsecConfig = import ./crowdsec.nix { inherit lib pkgs config containerVars; };
in {
  imports = [
    ./config.nix
    ./container.nix
    ./vars.nix
  ];

  options.services.crowdsec = {
    enable = mkEnableOption "CrowdSec security service";
    
    containerName = mkOption {
      type = types.str;
      default = "crowdsec";
      description = "Name of the CrowdSec container";
    };

    envFile = mkOption {
      type = types.path;
      description = "Path to environment file for CrowdSec";
    };

    networks = mkOption {
      type = types.listOf types.str;
      default = ["crowdsec"];
      description = "Networks to attach the container to";
    };

    volumes = mkOption {
      type = types.listOf types.str;
      default = [
        "/etc/localtime:/etc/localtime:ro"
        "/var/run/docker.sock:/var/run/docker.sock:ro"
        "/var/log/auth.log:/var/log/auth.log:ro"
        "/var/log/traefik:/var/log/traefik:ro"
        "./crowdsec/config:/etc/crowdsec"
        "./crowdsec/data:/var/lib/crowdsec/data"
      ];
      description = "Volume mounts for the container";
    };

    dns = mkOption {
      type = types.listOf types.str;
      default = ["1.1.1.1" "8.8.8.8"];
      description = "DNS servers for the container";
    };

    securityOpts = mkOption {
      type = types.listOf types.str;
      default = ["no-new-privileges=true"];
      description = "Security options for the container";
    };
  };

  config = mkIf cfg.enable {
    services.crowdsec = {
      containerName = "crowdsec";
      envFile = "/path/to/crowdsec.env";
      networks = ["crowdsec"];
      volumes = [
        "/etc/localtime:/etc/localtime:ro"
        "/var/run/docker.sock:/var/run/docker.sock:ro"
        "/var/log/auth.log:/var/log/auth.log:ro"
        "/var/log/traefik:/var/log/traefik:ro"
        "./crowdsec/config:/etc/crowdsec"
        "./crowdsec/data:/var/lib/crowdsec/data"
      ];
      dns = ["1.1.1.1" "8.8.8.8"];
      securityOpts = ["no-new-privileges=true"];
    };

    # Health check configuration
    services.crowdsec.healthCheck = {
      test = ["CMD" "cscli" "version"];
      interval = "20s";
      timeout = "2s";
      retries = 5;
      startPeriod = "10s";
    };

    # Container image configuration
    services.crowdsec.image = {
      name = "crowdsecurity/crowdsec";
      tag = "latest";
    };

    # Network configuration
    networking.crowdsec = {
      enable = true;
      ipv4Address = "172.41.254.254";
      subnet = "172.41.0.0/16";
    };
  };
}
