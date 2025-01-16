{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.networking;
in {
  options.networking = {
    networks = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          subnet = mkOption {
            type = types.str;
            description = "Network subnet";
          };
          gateway = mkOption {
            type = types.str;
            description = "Network gateway";
          };
          internal = mkOption {
            type = types.bool;
            default = false;
            description = "Internal only";
          };
#          user = mkOption {
#            type = types.str;
#            default = config.containerManager.user;
#            description = "User under which the Podman networks should be created";
#          };
        };
      });
      default = {};
      description = "Container networks configuration";
    };
  };

  config = {
    # Standard-Netzwerke - IMMER erstellen
    networking.networks = {
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
    };

    # Service-Konfiguration bleibt gleich
    systemd.services = mkMerge [
      (mapAttrs' (name: network: 
        nameValuePair "podman-network-${name}" {
          description = "Create Podman network ${name}";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
#            User = network.user;
            ExecStart = ''
              /bin/sh -c 'if ! ${pkgs.podman}/bin/podman network exists ${name}; then \
                echo "Creating network ${name}"; \
                ${pkgs.podman}/bin/podman network create \
                  --subnet ${network.subnet} \
                  --gateway ${network.gateway} \
                  ${name}; \
              else \
                echo "Network ${name} already exists (checked with podman network exists)"; \
                echo "Current networks:"; \
                ${pkgs.podman}/bin/podman network list; \
              fi'
            '';
          };
        }
      ) cfg.networks)
    ];
  };
}
