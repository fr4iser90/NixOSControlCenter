{ config, lib, pkgs, systemConfig, collectors, ui, reportLevels, ... }:

let
  cfg = systemConfig.core.management.system-manager.submodules.system-logging or {};
  libUtils = import ../lib/utils.nix { inherit lib; };

  # Generate system report by orchestrating collectors
  generateSystemReport = {
    # Sort collectors by priority
    sortedCollectors = libUtils.sortCollectorsByPriority
      (lib.filter (name: cfg.collectors.${name}.enable or false)
        (lib.attrNames collectors));

    # Generate report sections
    reportSections = lib.map (collectorName: {
      name = collectorName;
      content = if collectors.${collectorName} ? collect
        then collectors.${collectorName}.collect
        else "Collector ${collectorName} not available";
    }) sortedCollectors;

    # Format final report
    formattedReport = ''
      ${ui.text.header "NixOS System Report"}
      ${ui.tables.keyValue "Hostname" config.networking.hostName}
      ${ui.tables.keyValue "Generation" "$(readlink /nix/var/nix/profiles/system | cut -d'-' -f2)"}
      ${ui.tables.keyValue "Detail Level" cfg.defaultDetailLevel}
      ${ui.layout.separator "-" 50}

      ${lib.concatStringsSep "\n" (lib.map (section:
        libUtils.formatCollectorOutput section.name section.content
      ) reportSections)}
    '';
  };

in {
  # Export the report generation function
  inherit generateSystemReport;

  # Helper function to get active collectors
  getActiveCollectors = lib.filterAttrs
    (name: _: cfg.collectors.${name}.enable or false)
    collectors;

  # Helper function to validate collector availability
  validateCollectors = collectorNames:
    let
      availableCollectors = lib.attrNames collectors;
      missingCollectors = lib.filter
        (name: !(lib.elem name availableCollectors))
        collectorNames;
    in {
      valid = missingCollectors == [];
      missing = missingCollectors;
    };
}
