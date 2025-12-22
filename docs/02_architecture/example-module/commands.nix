{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.modules.example-module;
  ui = getModuleApi "cli-formatter";
in
  mkIf cfg.enable {
    # Create scripts using pkgs.writeShellScriptBin
    let
      mainScript = pkgs.writeShellScriptBin "ncc-example-module" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail
        
        # Parse arguments
        ACTION="${"$"}{1:-help}"
        
        case "$ACTION" in
          help|--help|-h)
            echo "Usage: ncc-example-module <action>"
            echo ""
            echo "Actions:"
            echo "  help     Show this help message"
            echo "  status   Show module status"
            ;;
          status)
            ${ui.messages.info "Example Module Status"}
            ${ui.tables.keyValue "Enabled" "true"}
            ${ui.tables.keyValue "Option 1" "${toString cfg.option1}"}
            ${ui.tables.keyValue "Option 2" "${toString cfg.option2}"}
            ;;
          *)
            ${ui.messages.error "Unknown action: $ACTION"}
            exit 1
            ;;
        esac
      '';
    in {
      # Register commands in command-center
      core.management.system-manager.submodules.cli-registry.commands = [
        {
          name = "example-module";
          description = "Example module command";
          category = "features";
          script = "${mainScript}/bin/ncc-example-module";
          arguments = [];
          dependencies = [];
          shortHelp = "example-module - Example module command";
          longHelp = ''
            Example module command for demonstration.
            
            Usage:
              ncc example-module <action>
            
            Actions:
              help     Show help message
              status   Show module status
          '';
        }
      ];
    };
  }

