# modules/system-management/preflight/runners/cli.nix
{ config, lib, pkgs, systemConfig, reportingConfig, ... }:

let
  inherit (lib) types;

  # Validierungs-Script
  validateResult = pkgs.writeScriptBin "validate-result" ''
    #!${pkgs.bash}/bin/bash
    RESULT="$1"
    VALIDATION="$2"
    
    if [ -n "$VALIDATION" ]; then
      eval "$VALIDATION '$RESULT'"
    else
      if [ "$RESULT" = "0" ]; then
        echo '{"success":true,"message":"Check passed"}'
      else
        echo '{"success":false,"message":"Check failed"}'
      fi
    fi
  '';

  # Check-Runner Funktion
  runCheck = name: checkSet: ''
    ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.detailed then ''
      ${reportingConfig.formatting.info "Running ${checkSet.name or name}..."}
    '' else ""}

    if [ -x "${checkSet.check}/bin/${checkSet.binary or name}" ]; then
      ${checkSet.check}/bin/${checkSet.binary or name}
      EXIT_CODE=$?
      
      if [ $EXIT_CODE -eq 0 ]; then
        ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.minimal then ''
          ${reportingConfig.formatting.success "${checkSet.name or name}: Check passed"}
        '' else ""}
      else
        ${reportingConfig.formatting.error "${checkSet.name or name}: Check failed"}
        FAILED=1
      fi
    else
      ${reportingConfig.formatting.error "${checkSet.name or name}: Check not executable"}
      FAILED=1
    fi
  '';

  # Haupt-Runner Script
  checkRunner = pkgs.writeScriptBin "run-system.preflight.checks" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    FAILED=0

    
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList runCheck config.system.preflight.checks)}
    
    if [ "$FAILED" -eq 1 ]; then
      exit 1
    fi
    
    ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.minimal then ''
      ${reportingConfig.formatting.success "All checks passed!"}
    '' else ""}
    exit 0
  '';

  # Neuer check-and-build Befehl
  checkAndBuild = pkgs.writeShellScriptBin "check-and-build" ''
    #!${pkgs.bash}/bin/bash
    
    if [ $# -eq 0 ]; then
      ${reportingConfig.formatting.error "No build command specified"}
      ${reportingConfig.formatting.info "Usage: check-and-build [nixos-rebuild options]"}
      ${reportingConfig.formatting.info "Example: check-and-build switch"}
      exit 1
    fi

    ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.standard then ''
      ${reportingConfig.formatting.section "NixOS System Build"}
      ${reportingConfig.formatting.info "Running preflight checks..."}
    '' else ""}

    if ! run-system.preflight.checks; then
      ${reportingConfig.formatting.error "Preflight checks failed!"}
      exit 1
    fi

    ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.standard then ''
      ${reportingConfig.formatting.success "Checks passed!"}
      ${reportingConfig.formatting.info "Running nixos-rebuild..."}
    '' else ""}

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
    environment.systemPackages = [ checkRunner checkAndBuild ];
  };
}