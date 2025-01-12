{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.features.system-logger;
  ui = config.features.terminal-ui.api;
  
  # Report Level Definition
  reportLevels = {
    minimal = 1;
    standard = 2;
    detailed = 3;
    full = 4;
  };

  # Collector-spezifische Optionen
  mkCollectorOptions = name: {
    enable = mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the ${name} collector";
    };

    detailLevel = mkOption {
      type = lib.types.nullOr (lib.types.enum (attrNames reportLevels));
      default = null;
      description = "Override detail level for ${name} collector";
    };

    priority = mkOption {
      type = lib.types.int;
      default = 100;
      description = "Execution priority for ${name} collector";
    };
  };

  # Verfügbare Collectors
  availableCollectors = [
    "profile"
    "bootloader"
    "bootentries"
    "packages"
  ];

  # Importiere aktive Collector-Module
  collectors = filterAttrs (name: _: cfg.collectors.${name}.enable) (
    listToAttrs (map (name: {
      inherit name;
      value = import ./collectors/${name}.nix { 
        inherit config lib pkgs systemConfig ui reportLevels; # ui statt colors/formatting
        currentLevel = reportLevels.${
          if cfg.collectors.${name}.detailLevel != null
          then cfg.collectors.${name}.detailLevel
          else cfg.defaultDetailLevel
        };
      };
    }) availableCollectors)
  );

in {
  options.features.system-logger = {
    enable = mkEnableOption "system logger";
    
    defaultDetailLevel = mkOption {
      type = lib.types.enum (attrNames reportLevels);
      default = "standard";
      description = "Default detail level for all reports";
    };

    collectors = mkOption {
      type = lib.types.submodule {
        options = listToAttrs (map (name: {
          name = name;
          value = mkOption {
            type = lib.types.submodule {
              options = mkCollectorOptions name;
            };
            default = {};
            description = "Configuration for the ${name} collector";
          };
        }) availableCollectors);
      };
      default = {};
      description = "Collector-specific configurations";
    };
  };

  config = mkMerge [
    # Default-Konfiguration
    {
      features.system-logger = {
        enable = mkDefault true;
        defaultDetailLevel = mkDefault (
          if systemConfig ? buildLogLevel 
          then systemConfig.buildLogLevel
          else "standard"
        );
      };
    }

    # Bedingte Konfiguration
    (mkIf cfg.enable {
      # Abhängigkeit von terminal-ui
      features.terminal-ui.enable = true;

      system.activationScripts.systemReport = {
        deps = [];
        text = let
          # Sortiere Collectors nach Priorität
          sortedCollectors = sort (a: b: 
            cfg.collectors.${a}.priority < cfg.collectors.${b}.priority
          ) (filter (name: cfg.collectors.${name}.enable) availableCollectors);

          # Generiere Reports
          reports = map (name: 
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
          
          ${concatStringsSep "\n" reports}
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
  ];
}