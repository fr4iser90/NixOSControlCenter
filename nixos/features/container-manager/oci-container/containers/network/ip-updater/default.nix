{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ipUpdater;
  containerVars = import ./vars.nix { inherit lib config; };
  updaterConfig = import ./updater.nix { inherit lib pkgs config containerVars; };
in {
  imports = [
    ./config.nix
    ./container.nix
    ./vars.nix
  ];

  options.services.ipUpdater = {
    enable = mkEnableOption "IP updater service";
    
    containerName = mkOption {
      type = types.str;
      default = "ip-updater";
      description = "Name of the IP updater container";
    };

    volumes = mkOption {
      type = types.listOf types.str;
      default = [
        "./traefik/dynamic-conf:/dynamic-conf:rw"
      ];
      description = "Volume mounts for the container";
    };

    command = mkOption {
      type = types.str;
      default = ''
        sh -c '
          update_ip() {
            CURRENT_IP=$$(cat /dynamic-conf/current_ip 2>/dev/null || echo "")
            NEW_IP=$$(curl -s https://api.ipify.org)
            
            if [ "$$NEW_IP" != "$$CURRENT_IP" ] && [ ! -z "$$NEW_IP" ]; then
              echo "IP changed from $$CURRENT_IP to $$NEW_IP"
              echo "$$NEW_IP" > /dynamic-conf/current_ip
              echo -e "http:\n  middlewares:\n    admin-whitelist:\n      ipWhiteList:\n        sourceRange:\n          - \"192.168.0.0/16\"\n          - \"10.8.0.0/24\"\n          - \"172.16.0.0/12\"\n          - \"172.40.0.0/16\"\n          - \"172.41.0.0/16\"\n          - \"$$NEW_IP/32\"" > /dynamic-conf/custom-ips.yml
              echo "Updated IP whitelist configuration"
            fi
          }
          
          apk add --no-cache curl
          while true; do
            update_ip
            sleep 300
          done'
      '';
      description = "Command to run in the container";
    };
  };

  config = mkIf cfg.enable {
    services.ipUpdater = {
      containerName = "ip-updater";
      volumes = [
        "./traefik/dynamic-conf:/dynamic-conf:rw"
      ];
    };

    # Container image configuration
    services.ipUpdater.image = {
      name = "alpine";
      tag = "latest";
    };

    # Restart policy
    services.ipUpdater.restartPolicy = "unless-stopped";
  };
}
