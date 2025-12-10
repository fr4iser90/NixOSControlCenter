{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = config.core.command-center or {};
  ui = config.core.cli-formatter.api;
  ccLib = import ../lib { inherit lib; };

  # Dynamische Inhalte vorbereiten
  # Get commands from systemConfig
  resolvedCommands = cfg.commands or [];
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

    # Hauptfunktion für Befehle
    function run_command() {
      local cmd="$1"
      shift
      if [[ -z "$cmd" ]]; then
        show_help
        exit 0
      fi
      case "$cmd" in
        help)
          show_command_help "$1"
          ;;
        ${caseBlock}
        *)
          ${ui.badges.error "Unknown command '$cmd'"}
          ${ui.text.newline}
          show_help
          exit 1
          ;;
      esac
    }

    # Einstiegspunkt
    run_command "$@"
  ''
