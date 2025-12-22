{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  cfg = getModuleConfig "system-logging";
  ui = config.core.management.system-manager.submodules.cli-formatter.api;

  # System Report Script
  systemReportScript = pkgs.writeShellScriptBin "ncc-log-system-report" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    # Function to display usage
    usage() {
        echo "Usage: ncc-log-system-report [OPTIONS]"
        echo ""
        echo "Generate system report with configured collectors"
        echo ""
        echo "Options:"
        echo "  -h, --help          Show this help message"
        echo "  -l, --level LEVEL   Override detail level (basic|info|debug|trace)"
        echo "  --list-collectors   List available collectors"
        echo "  --enable COLLECTOR  Enable specific collector"
        echo "  --disable COLLECTOR Disable specific collector"
        exit 0
    }

    # Parse arguments
    DETAIL_LEVEL=""
    ENABLE_COLLECTORS=()
    DISABLE_COLLECTORS=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -l|--level)
                DETAIL_LEVEL="$2"
                shift 2
                ;;
            --list-collectors)
                echo "Available collectors:"
                echo "  profile      - System profile information"
                echo "  bootloader   - Bootloader configuration"
                echo "  bootentries  - Boot entries"
                echo "  packages     - Installed packages"
                echo "  desktop      - Desktop environment settings"
                echo "  network      - Network configuration"
                echo "  services     - Systemd services status"
                echo "  sound        - Audio configuration"
                echo "  system-config- System configuration details"
                echo "  virtualization- Virtualization status"
                exit 0
                ;;
            --enable)
                ENABLE_COLLECTORS+=("$2")
                shift 2
                ;;
            --disable)
                DISABLE_COLLECTORS+=("$2")
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done

    # TODO: Implement actual report generation using NixOS module collectors
    echo "System report generation would go here"
    echo "Configured collectors: profile, bootloader, bootentries, packages"
    echo "Detail level: ''${DETAIL_LEVEL:-standard}"
  '';

in {
  # Export the script for use in commands.nix
  script = systemReportScript;
}
