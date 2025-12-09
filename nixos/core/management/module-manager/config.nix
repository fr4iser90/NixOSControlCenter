{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.core.management.module-manager or {};
  userConfigFile = ./module-manager-config.nix;
  symlinkPath = "/etc/nixos/configs/module-manager-config.nix";
in
  lib.mkMerge [
    {
      # Symlink management for user config (always runs)
      system.activationScripts.module-manager-config-symlink = ''
        mkdir -p "$(dirname "${symlinkPath}")"

        # Create default config if it doesn't exist
        if [ ! -f "${toString userConfigFile}" ]; then
          mkdir -p "$(dirname "${toString userConfigFile}")"
          cat > "${toString userConfigFile}" <<'EOF'
{
  # Module Manager Configuration
  # This is a core module that dynamically discovers all available NixOS modules
  # No user configuration needed - everything works automatically

  core = {
    management = {
    module-manager = {
      # Core module - always active, no enable option
      # This module provides the 'ncc module-manager' command for toggling modules
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
    # Module-manager is a core module that dynamically discovers all available modules
    # No additional system configuration needed - works dynamically
  ]

