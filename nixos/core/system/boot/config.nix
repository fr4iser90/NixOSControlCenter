{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.system.boot or {};
  userConfigFile = ./boot-config.nix;
  symlinkPath = "/etc/nixos/configs/boot-config.nix";
in
  lib.mkMerge [
    {
      # Symlink management for user config (always runs)
      system.activationScripts.boot-config-symlink = ''
        mkdir -p "$(dirname "${symlinkPath}")"

        # Create default config if it doesn't exist
        if [ ! -f "${toString userConfigFile}" ]; then
          mkdir -p "$(dirname "${toString userConfigFile}")"
          cat > "${toString userConfigFile}" <<'EOF'
{
  # Boot System Configuration
  # This is a core module that dynamically loads bootloader implementations
  # No user configuration needed - bootloader is selected via systemConfig.system.bootloader

  boot = {
    # Bootloader selection is handled centrally in system-config.nix
    # Available options: "systemd-boot", "grub", "refind"
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
    # Boot module implementation is handled in default.nix
  ]
