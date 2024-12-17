# modules/system-management/preflight/runners/cli.nix
{ config, lib, pkgs, systemConfig, ... }:

let
  inherit (lib) types;

  # Validierungs-Script
  validateResult = pkgs.writeScriptBin "validate-result" ''
    #!${pkgs.bash}/bin/bash
    RESULT="$1"
    VALIDATION="$2"
    
    # Führe die Validierung durch
    if [ -n "$VALIDATION" ]; then
      eval "$VALIDATION '$RESULT'"
    else
      # Standard-Validierung: Prüfe auf Exit-Code 0
      if [ "$RESULT" = "0" ]; then
        echo '{"success":true,"message":"Check passed"}'
      else
        echo '{"success":false,"message":"Check failed"}'
      fi
    fi
  '';

  # Check-Runner Funktion
  runCheck = name: checkSet: ''
    echo "Running ${checkSet.name or name}..."
    if [ -x "${checkSet.check}/bin/${checkSet.binary or name}" ]; then
      # Direkte Ausführung des Checks ohne Capture
      ${checkSet.check}/bin/${checkSet.binary or name}
      EXIT_CODE=$?
      
      if [ $EXIT_CODE -eq 0 ]; then
        # Nur den finalen Status ausgeben wenn der Check erfolgreich war
        echo "✓ ${checkSet.name or name}: Check passed"
      else
        echo "✗ ${checkSet.name or name}: Check failed"
        FAILED=1
      fi
    else
      echo "! ${checkSet.name or name}: Check not executable"
      FAILED=1
    fi
  '';

  # Haupt-Runner Script
  checkRunner = pkgs.writeScriptBin "run-system.preflight.checks" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    FAILED=0

    echo "Running system preflight checks..."
    
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList runCheck config.system.preflight.checks)}
    
    if [ "$FAILED" -eq 1 ]; then
      exit 1
    fi
    
    exit 0
  '';

  # Neuer check-and-build Befehl
  checkAndBuild = pkgs.writeShellScriptBin "check-and-build" ''
    #!${pkgs.bash}/bin/bash
    
    if [ $# -eq 0 ]; then
      echo "Usage: check-and-build [nixos-rebuild options]"
      echo "Example: check-and-build switch"
      exit 1
    fi

    echo "Running preflight checks..."
    if ! run-system.preflight.checks; then
      echo "Preflight checks failed!"
      exit 1
    fi

    echo "Checks passed! Running nixos-rebuild..."
    exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild "$@" 
  '';

in {
  options.system.preflight.checks = lib.mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        check = lib.mkOption {
          type = types.package;
          description = "The check script to run";
        };
        validate = lib.mkOption {
          type = types.str;
          default = "";
          description = "Optional validation command";
        };
        name = lib.mkOption {
          type = types.str;
          default = "";
          description = "Display name for the check";
        };
        binary = lib.mkOption {
          type = types.str;
          default = "";
          description = "Name of the binary to execute (if different from check name)";
        };
      };
    });
    default = {};
    description = "Set of system.preflight.checks to run";
  };

  config = {
    environment.systemPackages = [ checkRunner ];
  };
}