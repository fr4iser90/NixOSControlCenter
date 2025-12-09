# Checks Utility Functions
{ lib }:

{
  # Helper to create check script wrapper
  mkCheckScript = name: script: ''
    #!${pkgs.bash}/bin/bash
    echo "Running ${name} check..."
    ${script}
  '';

  # Helper to format check results
  formatCheckResult = success: message:
    if success then "✅ ${message}" else "❌ ${message}";

  # Get enabled checks from config
  getEnabledChecks = checks:
    lib.filterAttrs (_: check: check.enable or false) checks;

  # Run multiple checks and collect results
  runChecks = checks: lib.concatMapStringsSep "\n" (name: check: ''
    echo "Running ${name} check..."
    if ${check.script}; then
      echo "✅ ${name} check passed"
    else
      echo "❌ ${name} check failed"
      exit 1
    fi
  '') (lib.mapAttrsToList lib.nameValuePair (getEnabledChecks checks));
}
