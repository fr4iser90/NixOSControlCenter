{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getCurrentModuleMetadata, moduleName, ... }:

let
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";
  ccLib = import ../lib { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };
  rootTui = (import ../ui/tui/default.nix { inherit config lib pkgs; }).tuiScript;

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
      ${ui.text.normal "Usage: ncc <domain> [action]"}
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
      
      # No command → show TUI root menu
      if [[ -z "$cmd" ]]; then
        exec ${rootTui}/bin/ncc-ncc-tui
      fi
      
      # help command
      if [[ "$cmd" == "help" ]]; then
        show_command_help "$1"
        exit 0
      fi
      
      # Try hierarchical first if there's a second arg
      local action="$1"
      
      if [[ -n "$action" ]]; then
        # Has action → try hierarchical: ncc <domain> <action>
        local full_cmd="$cmd-$action"
        shift  # Remove action from $1
        
        # Try to execute as hierarchical command
        case "$full_cmd" in
          ${caseBlock}
          *)
            # Hierarchical not found → maybe it's a flat command with args
            # Restore action to args and try flat
            set -- "$action" "$@"
            case "$cmd" in
              ${caseBlock}
              *)
                ${ui.badges.error "Unknown command '$cmd $action'"}
                ${ui.text.newline}
                show_help
                exit 1
                ;;
            esac
            ;;
        esac
      else
        # No action → try flat command
        case "$cmd" in
          ${caseBlock}
          *)
            ${ui.badges.error "Unknown command or domain '$cmd'"}
            ${ui.text.newline}
            show_help
            exit 1
            ;;
        esac
      fi
    }

    # Einstiegspunkt
    run_command "$@"
  ''
