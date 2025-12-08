{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.management.logging or {};
  ui = config.core.cli-formatter.api;
  
  # Report Level Definition
  reportLevels = {
    minimal = 1;
    standard = 2;
    detailed = 3;
    full = 4;
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
  imports = [
    ./options.nix
  ];

  config = mkMerge [
    {
      systemConfig.management.logging.enable = mkDefault (systemConfig.management.logging.enable or true);
    }
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
      # features.terminal-ui.enable removed (cli-formatter is Core) = true;

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