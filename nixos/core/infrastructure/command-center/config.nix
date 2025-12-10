{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.core.infrastructure.command-center or {};
  userConfigFile = ./command-center-config.nix;
  symlinkPath = "/etc/nixos/configs/command-center-config.nix";

  # Import utilities
  ccLib = import ./lib { inherit lib; };

  # Import scripts from scripts/ directory
  mainScript = import ./scripts/main-script.nix { inherit config lib pkgs systemConfig; };
  aliases = import ./scripts/aliases.nix { inherit config lib pkgs systemConfig; };

  # Automatisch alle verwendeten Kategorien sammeln
  # CRITICAL: Use the final resolved commands from systemConfig, not the initial cfg.commands
  finalCommands = config.core.command-center.commands or [];
  usedCategories = ccLib.utils.getUniqueCategories finalCommands;

in
{
  config = lib.mkMerge [
    (lib.mkIf (cfg.enable or true) {
      # Symlink management (only when enabled)
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
      systemConfig.core.infrastructure.command-center.categories = usedCategories;
    })
    (lib.mkIf (cfg.enable or true) {
      # Module implementation (only when enabled)
      environment.systemPackages = [
        mainScript                  # Hauptbefehl
        aliases.nixcc               # Alternative Namen
        aliases.nixctl
        aliases.nix-center
        aliases.nix-control
      ];

      # Assertions for validation (temporarily disabled - commands are registered via systemConfig)
      # assertions = [
      #   {
      #     assertion = cfg.commands != [];
      #     message = "command-center: At least one command must be registered";
      #   }
      # ];
    })
  ];
}

