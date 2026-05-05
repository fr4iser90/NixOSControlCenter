# Example script: Main command entry point
# This is called by the command registered in commands.nix

{ pkgs, lib, cfg, ui, ... }:

pkgs.writeShellScriptBin "ncc-example-module-main" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail

  # Parse arguments
  ACTION="${"$"}{1:-help}"
  
  case "$ACTION" in
    help|--help|-h)
      echo "Usage: ncc-example-module-main <action>"
      echo ""
      echo "Actions:"
      echo "  help     Show this help message"
      echo "  run      Run main action"
      ;;
    run)
      ${ui.messages.info "Running main action"}
      # Call handler or processor here
      ;;
    *)
      ${ui.messages.error "Unknown action: $ACTION"}
      exit 1
      ;;
  esac
''

