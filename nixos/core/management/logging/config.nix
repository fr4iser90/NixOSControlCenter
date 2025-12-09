{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.management.logging or {};
  ui = config.core.cli-formatter.api;

  # Report Level Definition
  reportLevels = {
    basic = 1;
    info = 2;
    debug = 3;
    trace = 4;
  };

  # Verfügbare Collectors
  availableCollectors = [
    "profile"
    "bootloader"
    "bootentries"
    "packages"
  ];

  # Importiere aktive Collector-Module
  collectors = lib.filterAttrs (name: _: cfg.collectors.${name}.enable) (
    lib.listToAttrs (lib.map (name: {
      inherit name;
      value = import ./collectors/${name}.nix {
        inherit config lib pkgs systemConfig ui reportLevels;
        currentLevel = reportLevels.${
          if cfg.collectors.${name}.detailLevel != null
          then cfg.collectors.${name}.detailLevel
          else cfg.defaultDetailLevel
        };
      };
    }) availableCollectors)
  );

  userConfigFile = ./logging-config.nix;
  symlinkPath = "/etc/nixos/configs/logging-config.nix";
in
  lib.mkMerge [
    {
      # Symlink management (always runs)
      system.activationScripts.logging-config-symlink = ''
        mkdir -p "$(dirname "${symlinkPath}")"

        # Create default config if it doesn't exist
        if [ ! -f "${toString userConfigFile}" ]; then
          mkdir -p "$(dirname "${toString userConfigFile}")"
          cat > "${toString userConfigFile}" <<'EOF'
{
  # System Logging Configuration
  management = {
    logging = {
      enable = true;  # Enable system logging

      # Default detail level for all reports
      defaultDetailLevel = "info";

      # Collector-specific configurations
      collectors = {
        # System profile collector
        profile.enable = true;
        profile.detailLevel = null;  # Use default
        profile.priority = 100;

        # Bootloader information collector
        bootloader.enable = true;
        bootloader.detailLevel = null;
        bootloader.priority = 50;

        # Boot entry collector
        bootentries.enable = true;
        bootentries.detailLevel = null;
        bootentries.priority = 60;

        # Installed packages collector
        packages.enable = true;
        packages.detailLevel = null;
        packages.priority = 200;
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

    # Core API - always available
    {
      core.management.logging.system-logger.enable = lib.mkDefault true;
      core.management.logging.system-logger.defaultDetailLevel = lib.mkDefault (
        if systemConfig ? buildLogLevel
        then systemConfig.buildLogLevel
        else "standard"
      );
    }

    # Module implementation (when enabled)
    (lib.mkIf (cfg.enable or true) {
      system.activationScripts.systemReport = {
        deps = [];
        text = let
          # Sortiere Collectors nach Priorität
          sortedCollectors = lib.sort (a: b:
            cfg.collectors.${a}.priority < cfg.collectors.${b}.priority
          ) (lib.filter (name: cfg.collectors.${name}.enable) availableCollectors);

          # Generiere Reports
          reports = lib.map (name:
            if collectors ? ${name} && collectors.${name} ? collect
            then collectors.${name}.collect
            else throw "Invalid collector: ${name}"
          ) sortedCollectors;

        in ''
          ${ui.text.header "NixOS System Report"}
          ${ui.tables.keyValue "Hostname" config.networking.hostName}
          ${ui.tables.keyValue "Generation" "$(readlink /nix/var/nix/profiles/system | cut -d'-' -f2)"}
          ${ui.tables.keyValue "Detail Level" cfg.defaultDetailLevel}
          ${ui.layout.separator "-" 50}

          ${lib.concatStringsSep "\n" reports}
        '';
      };
    })

    # Exportiere reportingConfig für andere Module
    {
      _module.args.reportingConfig = {
        inherit ui reportLevels;
        currentLevel = reportLevels.${cfg.defaultDetailLevel};
      };
    }
  ]
