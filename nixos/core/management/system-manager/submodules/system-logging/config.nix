{ config, lib, pkgs, systemConfig, moduleConfig, ... }:
let
  configHelpers = import ../../../module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Module name: explizit definieren
  moduleName = "system-logging";
  cfg = config.systemConfig.${moduleConfig.${moduleName}.configPath} or {};
  # Use the template file as default config
  defaultConfig = builtins.readFile ./logging-config.nix;
  ui = config.core.management.system-manager.submodules.cli-formatter.api;

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
        inherit lib pkgs systemConfig ui reportLevels;
        currentLevel = reportLevels.${
          if effectiveCollectors.${name}.detailLevel != null
          then effectiveCollectors.${name}.detailLevel
          else cfg.defaultDetailLevel or "info"
        };
      };
    }) availableCollectors)
  );
in
  lib.mkMerge [
    # Config creation (always)
    {
      system.activationScripts."logging-config-setup" = ''
        mkdir -p "/etc/nixos/configs"
        if [ ! -f "/etc/nixos/configs/logging-config.nix" ]; then
          cat << 'EOF' > "/etc/nixos/configs/logging-config.nix"
${defaultConfig}
EOF
          chmod 644 "/etc/nixos/configs/logging-config.nix"
        fi
      '';
    }

    # Core API - always available
    {
      core.management.system-manager.submodules.system-logging.system-logger.enable = lib.mkDefault true;
      core.management.system-manager.submodules.system-logging.system-logger.defaultDetailLevel = lib.mkDefault (
        if systemConfig ? buildLogLevel
        then systemConfig.buildLogLevel
        else "standard"
      );
    }

    # Module implementation (always enabled)
    {
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
          ${ui.tables.keyValue "Detail Level" cfg.defaultDetailLevel}
          ${ui.layout.separator "-" 50}

          ${lib.concatStringsSep "\n" reports}
        '';
      };
    }

    # Exportiere reportingConfig für andere Module
    {
      _module.args.reportingConfig = {
        inherit ui reportLevels;
        currentLevel = reportLevels.${cfg.defaultDetailLevel or "info"};
      };
    }
  ]
