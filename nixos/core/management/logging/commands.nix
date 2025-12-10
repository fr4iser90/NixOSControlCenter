{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.management.logging or {};

  # Import the system report script
  systemReportScript = import ./scripts/system-report.nix {
    inherit config lib pkgs systemConfig;
  };

in {
  systemConfig.command-center.commands = lib.mkIf (cfg.enable or true) [
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
