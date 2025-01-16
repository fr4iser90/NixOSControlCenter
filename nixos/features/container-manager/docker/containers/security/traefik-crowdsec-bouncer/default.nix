{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.traefikCrowdsecBouncer;
  containerVars = import ./vars.nix { inherit lib config; };
  bouncerConfig = import ./bouncer.nix { inherit lib pkgs config containerVars; };
in {
  imports = [
    ./config.nix
    ./container.nix
    ./vars.nix
  ];

  options.services.traefikCrowdsecBouncer = {
    enable = mkEnableOption "Traefik CrowdSec bouncer service";
    
    containerName = mkOption {
      type = types.str;
      default = "traefik_crowdsec_bouncer";
      description = "Name of the Traefik CrowdSec bouncer container";
    };

    envFile = mkOption {
      type = types.path;
      description = "Path to environment file for the bouncer";
    };

    networks = mkOption {
      type = types.listOf types.str;
      default = ["crowdsec"];
      description = "Networks to attach the container to";
    };

    dns = mkOption {
      type = types.listOf types.str;
      default = ["1.1.1.1" "8.8.8.8"];
      description = "DNS servers for the container";
    };
  };

  config = mkIf cfg.enable {
    services.traefikCrowdsecBouncer = {
      containerName = "traefik_crowdsec_bouncer";
      envFile = "/path/to/traefik-crowdsec-bouncer.env";
      networks = ["crowdsec"];
      dns = ["1.1.1.1" "8.8.8.8"];
    };

    # Container image configuration
    services.traefikCrowdsecBouncer.image = {
      name = "fbonalair/traefik-crowdsec-bouncer";
      tag = "latest";
    };

    # Network configuration
    networking.traefikCrowdsecBouncer = {
      enable = true;
      ipv4Address = "172.41.254.252";
      subnet = "172.41.0.0/16";
    };
  };
}
