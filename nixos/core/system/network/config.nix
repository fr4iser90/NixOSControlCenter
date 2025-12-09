{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.system.network or {};
  userConfigFile = ./network-config.nix;
  symlinkPath = "/etc/nixos/configs/network-config.nix";
  configHelpers = config.core.management.system-manager.api.configHelpers;
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
in
  lib.mkMerge [
    {
      # Symlink management for user config (always runs)
      system.activationScripts.network-config-symlink = ''
        mkdir -p "$(dirname "${symlinkPath}")"

        # Create default config if it doesn't exist
        if [ ! -f "${toString userConfigFile}" ]; then
          mkdir -p "$(dirname "${toString userConfigFile}")"
          cat > "${toString userConfigFile}" <<'EOF'
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
EOF
        fi

        # Create/Update symlink
        if [ -L "${symlinkPath}" ] || [ -f "${symlinkPath}" ]; then
          CURRENT_TARGET=$(readlink -f "${symlinkPath}" 2>/dev/null || echo "")
          EXPECTED_TARGET=$(readlink -f "${toString userConfigFile}" 2>/dev/null || echo "")

          if [ "$CURRENT_TARGET" != "$EXPECTED_TARGET" ]; then
            if [ -f "${symlinkPath}" ] && [ ! -L "${symlinkPath}" ]; then
              cp "${symlinkPath}" "${symlinkPath}.backup.$(date +%s)"
            fi
            ln -sfn "${toString userConfigFile}" "${symlinkPath}"
          fi
        else
          ln -sfn "${toString userConfigFile}" "${symlinkPath}"
        fi
      '';
    }
    # Network module implementation is handled in default.nix
  ]
