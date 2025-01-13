{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.networking;
in {
  options.networking = {
    enable = mkEnableOption "Enable container networking";

    networks = mkOption {
      type = types.attrsOf types.networkConfig;
      default = {};
      description = "Container networks configuration";
    };

    defaultNetworks = mkOption {
      type = types.listOf types.str;
      default = [ "proxy" "crowdsec" ];
      description = "Default networks to create";
    };
  };

  config = mkIf cfg.enable {
    # Basis-Netzwerke erstellen
    systemd.services = mkMerge [
      (mapAttrs' (name: network: 
        nameValuePair "podman-network-${name}" {
          description = "Create Podman network ${name}";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = ''
              ${pkgs.podman}/bin/podman network create \
                --subnet=${network.subnet} \
                --gateway=${network.gateway} \
                ${optionalString network.attachable "--attachable"} \
                ${name} || true
            '';
            ExecStop = ''
              ${pkgs.podman}/bin/podman network rm ${name} || true
            '';
          };
        }
      ) cfg.networks)
    ];

    # Standard-Netzwerke
    networking.networks = mkMerge [
      (mkIf (elem "proxy" cfg.defaultNetworks) {
        proxy = {
          subnet = "172.40.0.0/16";
          gateway = "172.40.0.1";
        };
      })
      (mkIf (elem "crowdsec" cfg.defaultNetworks) {
        crowdsec = {
          subnet = "172.41.0.0/16";
          gateway = "172.41.0.1";
        };
      })
    ];
  };
}