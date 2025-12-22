{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
let
  cfg = getModuleConfig "system-logging";

  # Import the system report script
  systemReportScript = import ./scripts/system-report.nix {
    inherit config lib pkgs systemConfig;
  };

in {
  core.management.system-manager.submodules.cli-registry.commands = lib.mkIf (cfg.enable or true) [
    {
      name = "log-system-report";
      script = "${systemReportScript.script}/bin/ncc-log-system-report";
      category = "system";
      description = "Generate system report with configured collectors";
      helpText = ''
        Generate a comprehensive system report using configured collectors.

        Examples:
          ncc-log-system-report                    # Generate default report
          ncc-log-system-report --level debug     # Generate debug report
          ncc-log-system-report --list-collectors # List available collectors
          ncc-log-system-report --enable profile  # Enable specific collector
      '';
    }
  ];
}
