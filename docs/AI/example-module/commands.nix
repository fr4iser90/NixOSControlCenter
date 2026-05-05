{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, moduleName, ... }:

with lib;

let
  # Get config using getModuleConfig (includes template-config.nix defaults)
  cfg = getModuleConfig moduleName;
  # Get CLI registry API
  cliRegistry = getModuleApi "cli-registry";
  
  # Create scripts using pkgs.writeShellScriptBin
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
        echo "Example Module Status"
        echo "  Enabled: ${toString (cfg.enable or false)}"
        echo "  Option 1: ${cfg.option1 or "default-value"}"
        echo "  Option 2: ${toString (cfg.option2 or 42)}"
        ;;
      *)
        echo "Unknown action: $ACTION"
        exit 1
        ;;
    esac
  '';
in
{
  config = lib.mkMerge [
    # Register commands via CLI Registry API
    (cliRegistry.registerCommandsFor "example-module" [
      {
        name = "example-module";
        description = "Example module command";
        category = "features";
        script = "${mainScript}/bin/ncc-example-module";
        arguments = ["help" "status"];
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
    ])
  ];
}

