{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.features.infrastructure.homelab;
  userConfigFile = ./homelab-config.nix;
  symlinkPath = "/etc/nixos/configs/homelab-config.nix";
  configHelpers = import ../../management/module-manager/lib/config-helpers.nix { inherit pkgs lib; backupHelpers = import ../../management/system-manager/lib/backup-helpers.nix { inherit pkgs lib; }; };
  defaultConfig = ''
{
  # Homelab Manager Configuration
  # This feature manages Docker-based homelab environments
  # Supports both single-server and Docker Swarm modes

  features = {
    infrastructure = {
      homelab = {
        enable = false;

        # Docker Swarm configuration (optional)
        # swarm = null;        # Single-server mode
        # swarm = "manager";   # Swarm manager node
        # swarm = "worker";    # Swarm worker node

        # Docker stack configurations
        stacks = [
          # Example stack configuration:
          # {
          #   name = "my-stack";
          #   compose = "/path/to/docker-compose.yml";
          #   env = "/path/to/.env";  # Optional
          # }
        ];
      };
    };
  };
}
'';
in
  lib.mkMerge [
    (lib.mkIf (cfg.enable or false) {
      # Symlink management for user config (only when enabled)
      system.activationScripts.homelab-config-symlink = ''
        mkdir -p "$(dirname "${symlinkPath}")"

        # Create default config if it doesn't exist
        if [ ! -f "${toString userConfigFile}" ]; then
          mkdir -p "$(dirname "${toString userConfigFile}")"
          cat > "${toString userConfigFile}" <<'EOF'
{
  # Homelab Manager Configuration
  # This feature manages Docker-based homelab environments
  # Supports both single-server and Docker Swarm modes

  features = {
    infrastructure = {
      homelab = {
        enable = false;

        # Docker Swarm configuration (optional)
        # swarm = null;        # Single-server mode
        # swarm = "manager";   # Swarm manager node
        # swarm = "worker";    # Swarm worker node

        # Docker stack configurations
        stacks = [
          # Example stack configuration:
          # {
          #   name = "my-stack";
          #   compose = "/path/to/docker-compose.yml";
          #   env = "/path/to/.env";  # Optional
          # }
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

      # Enable feature by default if system config has it
      features.infrastructure.homelab.enable = lib.mkDefault (systemConfig.features.infrastructure.homelab.enable or false);
    })
    # Implementation is handled in default.nix
  ]
