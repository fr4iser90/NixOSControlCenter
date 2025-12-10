{ config, lib, pkgs, systemConfig, ... }:
let
  configHelpers = import ../../management/module-manager/lib/config-helpers.nix { inherit pkgs lib; backupHelpers = import ../../management/system-manager/lib/backup-helpers.nix { inherit pkgs lib; }; };
in
{
  config = lib.mkIf ((systemConfig.system.network.enable or false) || true)
    (configHelpers.createModuleConfig {
      moduleName = "network";
      defaultConfig = ''
{
  # Network System Configuration
  # This is a core module that configures basic networking
  # Advanced network configuration should be done in system-config.nix

  network = {
    # NetworkManager DNS configuration
    networkManager = {
      dns = "default";  # Options: "default", "systemd-resolved", "none"
    };

    # Networking services for firewall rules
    networking = {
      services = {
        # Service configurations would go here
        # Each service can have: exposure = "local"|"public", port, protocol, etc.
      };

      firewall = {
        trustedNetworks = [
          # Add trusted networks here, e.g.:
          # "192.168.1.0/24"
          # "10.0.0.0/8"
        ];
      };
    };
  };
}
'';
    });
  # Network module implementation is handled in default.nix
}
