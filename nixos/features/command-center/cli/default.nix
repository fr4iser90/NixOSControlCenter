{ config, lib, pkgs, ... }:

let
  # Zugriff auf die Terminal-UI-API
  ui = config.features.terminal-ui.api;

  # Befehle aus der Konfiguration
  cfg = config.features.command-center;

  # Generiert Case-Blöcke für Befehlsausführung
  generateExecCase = cmd: ''
    ${cmd.name})
      exec "${cmd.script}" "$@"
      ;;
  '';

  # Generiert Case-Blöcke für detaillierte Hilfe
  generateLongHelpCase = cmd: ''
    ${cmd.name})
      echo "${cmd.longHelp}"
      ;;
  '';

  # Dynamische Inhalte vorbereiten
  caseBlock = lib.concatMapStringsSep "\n  " generateExecCase cfg.commands;
  commandLongHelp = lib.concatMapStringsSep "\n  " generateLongHelpCase cfg.commands;
  commandList = lib.concatMapStringsSep "\n" (cmd: '' "  ${cmd.name} - ${cmd.description}"'') cfg.commands;
  validCommands = lib.concatStringsSep " " (map (cmd: cmd.name) cfg.commands);

  # Hauptskript für ncc
  mainScript = pkgs.writeScriptBin "ncc" ''
    #!/usr/bin/env bash

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
  '';

  # Alternativen für den Hauptbefehl erstellen
  nixcc = pkgs.writeScriptBin "nixcc" ''
    #!/usr/bin/env bash
    exec ${mainScript}/bin/ncc "$@"
  '';
  nixctl = pkgs.writeScriptBin "nixctl" ''
    #!/usr/bin/env bash
    exec ${mainScript}/bin/ncc "$@"
  '';
  nix-center = pkgs.writeScriptBin "nix-center" ''
    #!/usr/bin/env bash
    exec ${mainScript}/bin/ncc "$@"
  '';
  nix-control = pkgs.writeScriptBin "nix-control" ''
    #!/usr/bin/env bash
    exec ${mainScript}/bin/ncc "$@"
  '';

in {
  config = {
    environment.systemPackages = [
      mainScript   # Hauptbefehl
      nixcc        # Alternative Namen
      nixctl
      nix-center
      nix-control
    ];
  };
}
