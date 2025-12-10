{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.system.user or {};
  userConfigFile = ./user-config.nix;
  symlinkPath = "/etc/nixos/configs/user-config.nix";
  configHelpers = import ../../management/system-manager/lib/config-helpers.nix { inherit pkgs lib; backupHelpers = import ../../management/system-manager/lib/backup-helpers.nix { inherit pkgs lib; }; };
  defaultConfig = ''
{
  # User System Configuration
  # This is a core module that manages system users
  # User definitions are managed centrally in system-config.nix

  user = {
    # User configuration is handled in system-config.nix via systemConfig.users
    # This file serves as a placeholder for future user-specific settings
  };
}
'';
in
  lib.mkMerge [
    {
      # Symlink management for user config (always runs)
      system.activationScripts.user-config-symlink = ''
        mkdir -p "$(dirname "${symlinkPath}")"

        # Create default config if it doesn't exist
        if [ ! -f "${toString userConfigFile}" ]; then
          mkdir -p "$(dirname "${toString userConfigFile}")"
          cat > "${toString userConfigFile}" <<'EOF'
{
  # User System Configuration
  # This is a core module that manages system users
  # User definitions are managed centrally in system-config.nix

  user = {
    # User configuration is handled in system-config.nix via systemConfig.users
    # This file serves as a placeholder for future user-specific settings
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
    # User module implementation is handled in default.nix
  ]
