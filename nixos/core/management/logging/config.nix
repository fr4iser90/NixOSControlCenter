{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.core.management.logging or {};
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

  # Default collector configurations
  defaultCollectors = lib.listToAttrs (map (name: {
    inherit name;
    value = {
      enable = true;
      detailLevel = null;
      priority = 100;
    };
  }) availableCollectors);

  # Effective collectors (merge defaults with systemConfig)
  effectiveCollectors = defaultCollectors // (cfg.collectors or {});

  # Importiere aktive Collector-Module
  collectors = lib.filterAttrs (name: _: effectiveCollectors.${name}.enable) (
    lib.listToAttrs (lib.map (name: {
      inherit name;
      value = import ./collectors/${name}.nix {
        inherit config lib pkgs systemConfig ui reportLevels;
        currentLevel = reportLevels.${
          if effectiveCollectors.${name}.detailLevel != null
          then effectiveCollectors.${name}.detailLevel
          else config.systemConfig.core.management.logging.defaultDetailLevel or "info"
        };
      };
    }) availableCollectors)
  );

  configHelpers = import ../module-manager/lib/config-helpers.nix { inherit pkgs lib; backupHelpers = import ../system-manager/lib/backup-helpers.nix { inherit pkgs lib; }; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./logging-config.nix;
in
  lib.mkMerge [
    (lib.mkIf (cfg.enable or true) {
      # Create config on activation (always runs)
      # Uses new external config system
      (configHelpers.createModuleConfig {
        moduleName = "logging";
        defaultConfig = defaultConfig;
      });
    })

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
            effectiveCollectors.${a}.priority < effectiveCollectors.${b}.priority
          ) (lib.filter (name: effectiveCollectors.${name}.enable) availableCollectors);

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
          ${ui.tables.keyValue "Detail Level" config.systemConfig.core.management.logging.defaultDetailLevel}
          ${ui.layout.separator "-" 50}

          ${lib.concatStringsSep "\n" reports}
        '';
      };
    })

    # Exportiere reportingConfig für andere Module
    {
      _module.args.reportingConfig = {
        inherit ui reportLevels;
        currentLevel = reportLevels.${config.systemConfig.core.management.logging.defaultDetailLevel};
      };
    }
  ]
