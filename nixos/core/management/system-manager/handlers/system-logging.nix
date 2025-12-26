{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getCurrentModuleMetadata, ... }:

let
  # System Logging Handler
  # Bietet System-Reporting als reine Component

  metadata = getCurrentModuleMetadata ../.;
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

  # Importiere aktive Collector-Module
  collectors = lib.listToAttrs (lib.map (name: {
    inherit name;
    value = import ../components/system-logging/collectors/${name}.nix {
      inherit config lib pkgs systemConfig ui reportLevels;
      inherit getModuleConfig;
      currentLevel = reportLevels.info;  # Default level
    };
  }) availableCollectors);

in {
  # System Logging Component Implementation

  # System Report activation script
  system.activationScripts.systemReport = {
    deps = [];
    text = let
      # Sortiere Collectors nach Priorität
      sortedCollectors = lib.sort (a: b:
        defaultCollectors.${a}.priority < defaultCollectors.${b}.priority
      ) availableCollectors;

      # Generiere Reports
      reports = lib.map (name:
        if collectors ? ${name} && collectors.${name} ? collect
        then collectors.${name}.collect
        else "# Invalid collector: ${name}"
      ) sortedCollectors;

    in ''
      ${ui.text.header "NixOS System Report"}
      ${ui.tables.keyValue "Hostname" config.networking.hostName}
      ${ui.tables.keyValue "Generation" "$(readlink /nix/var/nix/profiles/system | cut -d'-' -f2)"}
      ${ui.layout.separator "-" 50}

      ${lib.concatStringsSep "\n" reports}
    '';
  };

  # Exportiere reportingConfig für andere Module
  _module.args.reportingConfig = {
    inherit ui reportLevels;
    currentLevel = reportLevels.info;
  };
}
