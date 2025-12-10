{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.features.infrastructure.bootentry;
  userConfigFile = ./bootentry-config.nix;
  symlinkPath = "/etc/nixos/configs/bootentry-config.nix";
  configHelpers = import ../../management/module-manager/lib/config-helpers.nix { inherit pkgs lib; backupHelpers = import ../../management/system-manager/lib/backup-helpers.nix { inherit pkgs lib; }; };
  defaultConfig = ''
{
  # Boot Entry Manager Configuration
  # This feature manages bootloader entries for systemd-boot, GRUB, and rEFInd

  features = {
    infrastructure = {
      bootentry = {
        enable = false;
        # Boot entry management is automatically enabled when this feature is active
        # No additional configuration needed - uses system bootloader configuration
      };
    };
  };
}
'';
in
  lib.mkMerge [
    (lib.mkIf (cfg.enable or false) {
      # Symlink management for user config (only when enabled)
      system.activationScripts.bootentry-config-symlink = ''
        mkdir -p "$(dirname "${symlinkPath}")"

        # Create default config if it doesn't exist
        if [ ! -f "${toString userConfigFile}" ]; then
          mkdir -p "$(dirname "${toString userConfigFile}")"
          cat > "${toString userConfigFile}" <<'EOF'
{
  # Boot Entry Manager Configuration
  # This feature manages bootloader entries for systemd-boot, GRUB, and rEFInd

  features = {
    infrastructure = {
      bootentry = {
        enable = false;
        # Boot entry management is automatically enabled when this feature is active
        # No additional configuration needed - uses system bootloader configuration
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
    })
    # Boot entry module implementation is handled in default.nix
  ]
