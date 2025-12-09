{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.command-center or {};
  userConfigFile = ./command-center-config.nix;
  symlinkPath = "/etc/nixos/configs/command-center-config.nix";

  # Import utilities
  ccLib = import ./lib { inherit lib; };

  # Import scripts from scripts/ directory
  mainScript = import ./scripts/main-script.nix { inherit config lib pkgs systemConfig; };
  aliases = import ./scripts/aliases.nix { inherit config lib pkgs systemConfig; };

  # Automatisch alle verwendeten Kategorien sammeln
  usedCategories = ccLib.utils.getUniqueCategories cfg.commands;

in
{
  config = lib.mkMerge [
    {
      # Symlink management (always runs, even if disabled)
      system.activationScripts.command-center-config-symlink = ''
        mkdir -p "$(dirname "${symlinkPath}")"

        # Create default config if it doesn't exist
        if [ ! -f "${toString userConfigFile}" ]; then
          mkdir -p "$(dirname "${toString userConfigFile}")"
          cat > "${toString userConfigFile}" <<'EOF'
{
  command-center = {
    enable = true;
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

      # Compute categories from commands
      systemConfig.command-center.categories = usedCategories;
    }
    (lib.mkIf (cfg.enable or true) {
      # Module implementation (only when enabled)
      environment.systemPackages = [
        mainScript                  # Hauptbefehl
        aliases.nixcc               # Alternative Namen
        aliases.nixctl
        aliases.nix-center
        aliases.nix-control
      ];

      # Assertions for validation
      assertions = [
        {
          assertion = cfg.commands != [];
          message = "command-center: At least one command must be registered";
        }
      ];
    })
  ];
}

