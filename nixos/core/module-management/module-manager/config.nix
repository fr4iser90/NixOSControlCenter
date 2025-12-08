{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.module-management.module-manager or {};
  userConfigFile = "/etc/nixos/core/module-management/module-manager/user-configs/module-manager-config.nix";
  symlinkPath = "/etc/nixos/configs/module-manager-config.nix";
  defaultConfig = ''
{
  module-management.module-manager = {
    enable = true;
  };
}
'';
in
  lib.mkMerge [
    {
      # Symlink management (always runs)
      system.activationScripts.module-manager-config-symlink = ''
        mkdir -p "$(dirname "${symlinkPath}")"
        mkdir -p "$(dirname "${userConfigFile}")"
        
        if [ ! -f "${userConfigFile}" ]; then
          cat > "${userConfigFile}" <<'EOF'
${defaultConfig}
EOF
        fi
        
        if [ -L "${symlinkPath}" ] || [ -f "${symlinkPath}" ]; then
          CURRENT_TARGET=$(readlink -f "${symlinkPath}" 2>/dev/null || echo "")
          EXPECTED_TARGET=$(readlink -f "${userConfigFile}" 2>/dev/null || echo "")
          
          if [ "$CURRENT_TARGET" != "$EXPECTED_TARGET" ]; then
            if [ -f "${symlinkPath}" ] && [ ! -L "${symlinkPath}" ]; then
              cp "${symlinkPath}" "${symlinkPath}.backup.$(date +%s)"
            fi
            ln -sfn "${userConfigFile}" "${symlinkPath}"
          fi
        else
          ln -sfn "${userConfigFile}" "${symlinkPath}"
        fi
      '';
    }
    (lib.mkIf (cfg.enable or true) {
      # Module manager implementation
    })
  ];

