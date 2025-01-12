{ config, lib, pkgs, ... }:

let
  ui = config.features.terminal-ui.api;
  cfg = config.features.command-center;

  # Hauptscript
  mainScript = pkgs.writeScriptBin "ncc" ''
    #!${pkgs.bash}/bin/bash
    
    # Hilfe anzeigen
    function show_help() {
      ${ui.text.header "NixOS Control Center"}
      echo "Usage: ncc <command> [arguments]"
      echo ""
      echo "Commands:"
      ${builtins.concatStringsSep "\n" (map (cmd: 
        "  ${cmd.name} - ${cmd.description}"
      ) (builtins.attrValues cfg.commands))}
    }

    # Befehl ausführen
    function run_command() {
      local cmd="$1"
      shift
      
      if [ -z "$cmd" ]; then
        show_help
        exit 1
      fi

      case "$cmd" in
        ${builtins.concatStringsSep "\n        " (map (name: 
          "${name})
            exec ${toString (lib.getAttr name cfg.commands).script} \"$@\"
            ;;"
        ) (builtins.attrNames cfg.commands))}
        *)
          ${ui.messages.error "Unknown command: $cmd"}
          exit 1
          ;;
      esac
    }

    run_command "$@"
  '';

  # Symlinks für alternative Namen
  nixcc = pkgs.writeScriptBin "nixcc" ''
    #!${pkgs.bash}/bin/bash
    exec ${mainScript}/bin/ncc "$@"
  '';

  nixctl = pkgs.writeScriptBin "nixctl" ''
    #!${pkgs.bash}/bin/bash
    exec ${mainScript}/bin/ncc "$@"
  '';

  nix-center = pkgs.writeScriptBin "nix-center" ''
    #!${pkgs.bash}/bin/bash
    exec ${mainScript}/bin/ncc "$@"
  '';

  nix-control = pkgs.writeScriptBin "nix-control" ''
    #!${pkgs.bash}/bin/bash
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