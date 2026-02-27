{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getCurrentModuleMetadata, moduleName, ... }:

let
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";
  ccLib = import ../lib { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };

  # Dynamische Inhalte vorbereiten
  # Get commands from CLI Registry API (collects from all modules)
  resolvedCommands = cliRegistry.getRegisteredCommands config;
  caseBlock = lib.concatMapStringsSep "\n  " ccLib.utils.generateExecCase resolvedCommands;
  commandLongHelp = lib.concatMapStringsSep "\n  " ccLib.utils.generateLongHelpCase resolvedCommands;
  commandList = ccLib.utils.generateCommandList resolvedCommands;
  validCommands = ccLib.utils.getValidCommands resolvedCommands;

in
  pkgs.writeScriptBin "ncc" ''
    #!/usr/bin/env bash

    # SIGINT (Strg+C) abfangen
    function handle_interrupt() {
      ${ui.badges.error "Operation cancelled"}
      exit 0
    }
    trap handle_interrupt INT

    # Hilfefunktion anzeigen
    function show_help() {
      ${ui.text.header "NixOS Control Center"}
      ${ui.text.normal "Usage: ncc <command> [arguments]"}
      ${ui.text.normal "       ncc help <command>"}
      ${ui.text.newline}
      ${ui.text.subHeader "Available commands:"}
      echo "${commandList}"
      ${ui.text.newline}
      ${ui.text.normal "Use 'ncc help <command>' for more details on a specific command."}
    }

    # Detaillierte Hilfe für Befehle anzeigen
    function show_command_help() {
      local cmd="$1"
      if [[ -z "$cmd" ]]; then
        show_help
        exit 0
      fi
      case "$cmd" in
        ${commandLongHelp}
        *)
          ${ui.badges.error "Unknown command '$cmd'"}
          ${ui.text.newline}
          show_help
          exit 1
          ;;
      esac
    }

    # Hierarchische Command Resolution
    function run_command() {
      local cmd="$1"
      shift
      
      # No command → show help
      if [[ -z "$cmd" ]]; then
        show_help
        exit 0
      fi
      
      # help command
      if [[ "$cmd" == "help" ]]; then
        show_command_help "$1"
        exit 0
      fi
      
      # Check if it's a direct command (flat)
      case "$cmd" in
        ${caseBlock}
        *)
          # Not a direct command → could be hierarchical
          # Try: ncc <domain> <action> [args]
          local action="$1"
          
          if [[ -z "$action" ]]; then
            # No action → try to execute domain command (TUI)
            # Example: ncc system → execute system TUI
            case "$cmd" in
              ${caseBlock}
              *)
                ${ui.badges.error "Unknown command or domain '$cmd'"}
                ${ui.text.newline}
                show_help
                exit 1
                ;;
            esac
          else
            # Has action → try hierarchical: ncc <domain> <action>
            shift  # Remove action from args
            local full_cmd="$cmd-$action"
            
            # Try to execute as hierarchical command
            case "$full_cmd" in
              ${caseBlock}
              *)
                ${ui.badges.error "Unknown command '$cmd $action'"}
                ${ui.text.newline}
                show_help
                exit 1
                ;;
            esac
          fi
          ;;
      esac
    }

    # Einstiegspunkt
    run_command "$@"
  ''
