{ config, pkgs, lib, ... }:

let
  # Default networks setup
  standardNetworks = {
    proxy = {
      subnet = "172.40.0.0/16";
      gateway = "172.40.0.1";
    };
    security = {
      subnet = "172.41.0.0/16";
      gateway = "172.41.0.1";
    };
    database = {
      subnet = "172.42.0.0/16";
      gateway = "172.42.0.1";
    };
    backup = {
      subnet = "172.43.0.0/16";
      gateway = "172.43.0.1";
    };
    monitoring = {
      subnet = "172.44.0.0/16";
      gateway = "172.44.0.1";
    };
    media = {
      subnet = "172.45.0.0/16";
      gateway = "172.45.0.1";
    };
    storage = {
      subnet = "172.46.0.0/16";
      gateway = "172.46.0.1";
    };
    management = {
      subnet = "172.47.0.0/16";
      gateway = "172.47.0.1";
    };
    games = {
      subnet = "172.50.0.0/16";
      gateway = "172.50.0.1";
    };
  };

  # Choose container manager (Podman or Docker)
  containerManager = config.containerManager.containerManager or "podman";

  # Define the network creation command based on the container manager
  createNetworkCmd = if containerManager == "podman" then
    "${pkgs.podman}/bin/podman network create"
  else if containerManager == "docker" then
    "${pkgs.docker}/bin/docker network create"
  else
    throw "Unsupported container manager: ${containerManager}";

  # Generate the systemd service for network creation dynamically
  networkServices = lib.mapAttrs (name: network: {
    "create-${containerManager}-network-${name}" = {
      description = "Create ${containerManager} network ${name}";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      ExecStart = ''
        /bin/sh -c "\
        if ! ${createNetworkCmd} --subnet ${network.subnet} --gateway ${network.gateway} ${name}; then \
          echo 'Network ${name} already exists'; \
        else \
          echo 'Network ${name} created with subnet ${network.subnet} and gateway ${network.gateway}'; \
        fi"
      '';
      };
    };
  }) standardNetworks;

in {
  config.containerManager.networks = standardNetworks;
  options.containerManager.networks = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        subnet = lib.mkOption {
          type = lib.types.str;
          description = "Network subnet";
        };
        gateway = lib.mkOption {
          type = lib.types.str;
          description = "Network gateway";
        };
        internal = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Internal only";
        };
      };
    });
    default = standardNetworks;
    description = "Container networks configuration";
  };

  

  # Add dynamically generated systemd services for container networks
  config.systemd.services = lib.mkMerge (lib.attrValues networkServices);
}
