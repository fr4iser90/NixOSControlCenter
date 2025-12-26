{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:
let
  cfg = getModuleConfig "system-logging";
  cliRegistry = getModuleApi "cli-registry";

  # Import the system report script
  systemReportScript = import ./scripts/system-report.nix {
    inherit config lib pkgs systemConfig;
  };

in {
  config = lib.mkMerge [
    (lib.mkIf (cfg.enable or true)
      (cliRegistry.registerCommandsFor "system-logging" [
    {
      name = "log-system-report";
      script = "${systemReportScript.script}/bin/ncc-log-system-report";
      category = "system";
      description = "Generate system report with configured collectors";
      shortHelp = "log-system-report - Generate system report";
      longHelp = ''
        Generate a comprehensive system report using configured collectors.

        Examples:
          ncc-log-system-report                    # Generate default report
          ncc-log-system-report --level debug     # Generate debug report
          ncc-log-system-report --list-collectors # List available collectors
          ncc-log-system-report --enable profile  # Enable specific collector
      '';
    }
    ];
    })
  ];
}
