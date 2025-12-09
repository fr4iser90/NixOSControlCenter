{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.management.checks or {};
  userConfigFile = ./checks-config.nix;
  symlinkPath = "/etc/nixos/configs/checks-config.nix";

  # CLI formatter API
  ui = config.core.cli-formatter.api;

  # Import scripts from scripts/ directory
  postbuildScript = import ./scripts/postbuild-checks.nix { inherit config lib pkgs systemConfig; };
  prebuildCheckScript = import ./scripts/prebuild-checks.nix { inherit config lib pkgs systemConfig; };

  # Postbuild checks implementation (moved from postbuild/default.nix)
  postbuildCfg = cfg.postbuild or {};

  # Prebuild checks implementation (moved from prebuild/default.nix)
  prebuildCfg = cfg.prebuild or {};
in
{
  config = lib.mkMerge [
    {
      # Symlink management (always runs, even if disabled)
      system.activationScripts.checks-config-symlink = ''
        mkdir -p "$(dirname "${symlinkPath}")"

        # Create default config if it doesn't exist
        if [ ! -f "${toString userConfigFile}" ]; then
          mkdir -p "$(dirname "${toString userConfigFile}")"
          cat > "${toString userConfigFile}" <<'EOF'
{
  management = {
    checks = {
      enable = true;
      postbuild = {
        enable = true;
        checks = {
          passwords.enable = true;
          filesystem.enable = true;
          services.enable = true;
        };
      };
      prebuild = {
        enable = true;
        checks = {
          cpu.enable = true;
          gpu.enable = true;
          memory.enable = true;
          users.enable = true;
        };
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
    (lib.mkIf (cfg.enable or true) {
      # Module implementation (only when enabled)
      environment.systemPackages = with pkgs; [
        pciutils
        usbutils
        lshw
        prebuildCheckScript
      ] ++ lib.optional (postbuildCfg.enable or true) postbuildScript;

      # Postbuild activation script
      system.activationScripts.postbuildChecks = lib.mkIf (postbuildCfg.enable or true) {
        deps = [ "users" "groups" ];
        text = ''
          echo "Running postbuild checks..."
          ${postbuildScript}/bin/nixos-postbuild
        '';
      };

      # Import prebuild check modules
      imports = lib.optional (prebuildCfg.enable or true) ./prebuild/checks/hardware/utils.nix
              ++ lib.optional (prebuildCfg.enable or true) ./prebuild/checks/hardware/gpu.nix
              ++ lib.optional (prebuildCfg.enable or true) ./prebuild/checks/hardware/cpu.nix
              ++ lib.optional (prebuildCfg.enable or true) ./prebuild/checks/hardware/memory.nix
              ++ lib.optional (prebuildCfg.enable or true) ./prebuild/checks/system/users.nix;
    })
  ];
}