{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, nixifyModuleName, ... }:

with lib;

let
  # moduleName aus _module.args - NUR EINMAL berechnet in default.nix!
  moduleName = nixifyModuleName;
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  
  # Nixify Service Manager Script
  nixifyServiceScript = pkgs.writeScriptBin "ncc-nixify" ''
    #!${pkgs.bash}/bin/bash
    # Nixify Service Manager
    
    set -euo pipefail
    
    ACTION=''${1:-help}
    
    case "$ACTION" in
      service)
        SUBACTION=''${2:-help}
        case "$SUBACTION" in
          start)
            echo "Starting Nixify web service..."
            systemctl start nixify-service
            systemctl status nixify-service
            ;;
          stop)
            echo "Stopping Nixify web service..."
            systemctl stop nixify-service
            ;;
          status)
            systemctl status nixify-service
            ;;
          restart)
            echo "Restarting Nixify web service..."
            systemctl restart nixify-service
            systemctl status nixify-service
            ;;
          logs)
            journalctl -u nixify-service -f
            ;;
          *)
            echo "Usage: ncc nixify service {start|stop|status|restart|logs}"
            exit 1
            ;;
        esac
        ;;
      list)
        echo "Listing Nixify sessions..."
        # TODO: Implement session listing
        echo "Session listing not yet implemented"
        ;;
      show)
        SESSION_ID=''${2:-}
        if [ -z "$SESSION_ID" ]; then
          echo "Usage: ncc nixify show <session-id>"
          exit 1
        fi
        echo "Showing session: $SESSION_ID"
        # TODO: Implement session details
        echo "Session details not yet implemented"
        ;;
      download)
        SESSION_ID=''${2:-}
        if [ -z "$SESSION_ID" ]; then
          echo "Usage: ncc nixify download <session-id>"
          exit 1
        fi
        echo "Downloading session: $SESSION_ID"
        # TODO: Implement download
        echo "Download not yet implemented"
        ;;
      help|*)
        cat <<EOF
Nixify - Windows/macOS/Linux → NixOS System-DNA-Extractor

Usage: ncc nixify <command> [options]

Commands:
  service <action>    Manage web service
    start             Start web service
    stop              Stop web service
    status            Show service status
    restart           Restart web service
    logs              Show service logs (follow mode)
  
  list                List all sessions
  show <session-id>   Show session details
  download <session-id>  Download config/ISO for session
  
Examples:
  ncc nixify service start    # Start web service
  ncc nixify service status    # Check service status
  ncc nixify list             # List all sessions
  ncc nixify show abc123      # Show session details
  ncc nixify download abc123  # Download config/ISO

For more information, see: doc/NIXIFY_ARCHITECTURE.md
EOF
        exit 0
        ;;
    esac
  '';
in
{
  config = lib.mkMerge [
    (cliRegistry.registerCommandsFor "nixify" [
      {
        name = "nixify";
        type = "manager";
        description = "Windows/macOS/Linux → NixOS System-DNA-Extractor";
        script = "${nixifyServiceScript}/bin/ncc-nixify";
        category = "specialized";
        shortHelp = "nixify - Extract system DNA and generate NixOS configs";
        longHelp = ''
          Nixify helps users migrate from Windows/macOS/Linux to NixOS by:
          
          1. Extracting system state (installed programs, settings, hardware)
          2. Mapping programs to NixOS packages/modules
          3. Generating declarative NixOS configurations
          4. Building custom ISO images (optional)
          
          Usage:
            ncc nixify service start    # Start web service
            ncc nixify service status   # Check service status
            ncc nixify list             # List all sessions
            ncc nixify show <id>        # Show session details
            ncc nixify download <id>    # Download config/ISO
          
          For detailed documentation, see:
          - doc/NIXIFY_ARCHITECTURE.md
          - doc/NIXIFY_WORKFLOW.md
        '';
      }
    ])
  ];
}
