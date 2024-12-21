{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.system.reporting or full;
  
  # Importiere gemeinsame Bibliotheken
  colors = import ./lib/colors.nix;
  formatting = import ./lib/formatting.nix { inherit lib colors; };
  types = import ./lib/types.nix;

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
    #"desktop"
    "packages"
    #"network"
    #"services"
    #"sound"
    #"virtualization"
  ];

  # Importiere aktive Collector-Module
  collectors = filterAttrs (name: _: cfg.collectors.${name}.enable) (
    listToAttrs (map (name: {
      inherit name;
      value = import ./collectors/${name}.nix { 
        inherit config lib pkgs colors formatting reportLevels systemConfig; # systemConfig hinzugefügt
        currentLevel = reportLevels.${
          if cfg.collectors.${name}.detailLevel != null
          then cfg.collectors.${name}.detailLevel
          else cfg.defaultDetailLevel
        };
      };
    }) availableCollectors)
  );

in {
  options.system.reporting = {
    enable = mkEnableOption "system reporting";
    
    defaultDetailLevel = mkOption {
      type = lib.types.enum (attrNames reportLevels);
      default = "standard";
      description = "Default detail level for all reports";
    };

    collectors = mkOption {
      type = lib.types.submodule {
        options = listToAttrs (map (name: {
          name = name;
          value = mkOption {  # Hier die Änderung
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
      system.reporting = {
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
          ${formatting.header colors.blue "NixOS System Report"}
          ${formatting.keyValue "Hostname" config.networking.hostName}
          ${formatting.keyValue "Generation" "$(readlink /nix/var/nix/profiles/system | cut -d'-' -f2)"}
          ${formatting.keyValue "Detail Level" cfg.defaultDetailLevel}
          ${formatting.separator "-" 50}
          
          ${concatStringsSep "\n" reports}
        '';
      };
    })

    # Exportiere reportingConfig für andere Module
    {
      _module.args.reportingConfig = {
        inherit formatting colors;
        reportLevels = reportLevels;
        currentLevel = reportLevels.${cfg.defaultDetailLevel};
      };
    }
  ];
}