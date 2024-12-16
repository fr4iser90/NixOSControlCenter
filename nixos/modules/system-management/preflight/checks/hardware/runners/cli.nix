# modules/system-management/preflight/runners/cli.nix
{ config, lib, pkgs, ... }:

let
  inherit (lib) types;

  runCheck = name: check: ''
    echo "Running ${check.name}..."
    RESULT="$(${check.check})"
    VALIDATION="$(${validate-result "$RESULT" check.validate})"
    
    if [ "$(echo "$VALIDATION" | jq -r .success)" = "true" ]; then
      echo "✓ ${check.name}: $(echo "$VALIDATION" | jq -r .message)"
    else
      echo "✗ ${check.name}: $(echo "$VALIDATION" | jq -r .message)"
      FAILED=1
    fi
  '';

  validate-result = pkgs.writeScript "validate-result" ''
    #!${pkgs.bash}/bin/bash
    RESULT="$1"
    # Validation-Logik hier
  '';

  checkRunner = pkgs.writeScriptBin "run-system-checks" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    FAILED=0

    echo "Running system preflight checks..."
    
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList runCheck config.system.checks)}
    
    if [ "$FAILED" -eq 1 ]; then
      echo "Some checks failed. Please review the messages above."
      exit 1
    fi
    
    echo "All checks passed successfully!"
  '';

in {
  environment.systemPackages = [ checkRunner ];
}