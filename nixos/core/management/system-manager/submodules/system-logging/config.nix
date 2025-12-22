{ config, lib, pkgs, systemConfig, moduleConfig, getModuleApi, ... }:
let
  configHelpers = import ../../../module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Module name: explizit definieren
  moduleName = "system-logging";
  cfg = systemConfig.${moduleConfig.${moduleName}.configPath} or {};
  # Use the template file as default config
  defaultConfig = builtins.readFile ./logging-config.nix;
  ui = getModuleApi "cli-formatter";

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
        getModuleConfig = moduleConfig.getModuleConfig;
        currentLevel = reportLevels.${
          if effectiveCollectors.${name}.detailLevel != null
          then effectiveCollectors.${name}.detailLevel
          else config.core.management.system-manager.submodules.system-logging.defaultDetailLevel or "info"
        };
      };
    }) availableCollectors)
  );
in
  lib.mkMerge [
    # Config creation (always)
    {
      system.activationScripts."logging-config-setup" = let
        configPath = moduleConfig.${moduleName}.configPath;
        configFilePath = "/etc/nixos/configs/" + (builtins.replaceStrings ["."] ["/"] configPath) + "/config.nix";
      in ''
        mkdir -p "/etc/nixos/configs"
        if [ ! -f "${configFilePath}" ]; then
          mkdir -p "$(dirname "${configFilePath}")"
          cat << 'EOF' > "${configFilePath}"
${defaultConfig}
EOF
          chmod 644 "${configFilePath}"
        fi
      '';
    }

    # Core API - always available
    {
      core.management.system-manager.submodules.system-logging.enable = lib.mkDefault true;
      core.management.system-manager.submodules.system-logging.defaultDetailLevel = lib.mkDefault (
        if systemConfig ? buildLogLevel && builtins.elem systemConfig.buildLogLevel ["basic" "info" "debug" "trace"]
        then systemConfig.buildLogLevel
        else "info"
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
          ${ui.tables.keyValue "Detail Level" config.core.management.system-manager.submodules.system-logging.defaultDetailLevel}
          ${ui.layout.separator "-" 50}

          ${lib.concatStringsSep "\n" reports}
        '';
      };
    }

        # Exportiere reportingConfig für andere Module
        {
          _module.args.reportingConfig = {
            inherit ui reportLevels;
        currentLevel = reportLevels.${config.core.management.system-manager.submodules.system-logging.defaultDetailLevel or "info"};
          };
        }
  ]
