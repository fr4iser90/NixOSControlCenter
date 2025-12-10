{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.core.cli-formatter or {};

  colors = import ./colors.nix;

  core = import ./core {
    inherit lib colors;
    inherit (cfg) config;
  };

  components = import ./components {
    inherit lib colors;
    inherit (cfg) config;
  };

  interactive = import ./interactive {
    inherit lib colors;
    inherit (cfg) config;
  };

  status = import ./status {
    inherit lib colors;
    inherit (cfg) config;
  };

  # API definition - always available
  apiValue = {
    inherit colors;
    inherit (core) text layout;
    inherit (components) lists tables progress boxes;
    inherit (interactive) prompts spinners;
    inherit (status) messages badges;
  };

  # User config file path
  userConfigFile = ./cli-formatter-config.nix;
  symlinkPath = "/etc/nixos/configs/cli-formatter-config.nix";

in
  lib.mkMerge [
    (lib.mkIf (cfg.enable or true) {
      # Symlink management (only when enabled)
      system.activationScripts.cli-formatter-config-symlink = ''
        mkdir -p "$(dirname "${symlinkPath}")"

        # Create default config if it doesn't exist
        if [ ! -f "${toString userConfigFile}" ]; then
          mkdir -p "$(dirname "${toString userConfigFile}")"
          cat > "${toString userConfigFile}" <<'EOF'
{
  core = {
    cli-formatter = {
      enable = true;  # CLI formatter is always enabled as infrastructure
      config = {
        # User customizations here
        # colors.theme = "dark";
        # formatting.enableUnicode = true;
      };
      components = {
        # example = {
        #   enable = false;
        #   refreshInterval = 10;
        #   template = "Custom component template";
        # };
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

      # API is always available (not dependent on cfg.enable)
      core.cli-formatter.api = apiValue;
    })
  ]
