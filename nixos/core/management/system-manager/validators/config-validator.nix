{ pkgs, lib, ... }:

let
  # Validation script that validates system-config.nix structure
  validateSystemConfig = pkgs.writeShellScriptBin "ncc-validate-config" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    SYSTEM_CONFIG="/etc/nixos/system-config.nix"   # SYSTEMCONFIG EXISTIERT NICHT MEHR!!!!
    CONFIGS_DIR="/etc/nixos/configs"
    
    ERRORS=0
    WARNINGS=0
    
    # Check if system-config.nix exists
    if [ ! -f "$SYSTEM_CONFIG" ]; then
      echo "ERROR: system-config.nix not found at $SYSTEM_CONFIG"
      exit 1
    fi
    
    echo "Validating system-config.nix..."
    
    # Validate Nix syntax
    if ! ${pkgs.nix}/bin/nix-instantiate --parse "$SYSTEM_CONFIG" >/dev/null 2>&1; then
      echo "ERROR: system-config.nix has invalid Nix syntax"
      ERRORS=$((ERRORS + 1))
    else
      echo "✓ Nix syntax is valid"
    fi
    
    # Check for required critical values
    CRITICAL_VALUES=(
      "systemType"
      "hostName"
      "system.channel"
      "system.bootloader"
      "allowUnfree"
      "users"
      "timeZone"
    )
    
    for value in "''${CRITICAL_VALUES[@]}"; do
      if ! ${pkgs.nix}/bin/nix-instantiate --eval --strict -E \
        "(import $SYSTEM_CONFIG).$value or null" >/dev/null 2>&1; then
        echo "WARNING: $value not found in system-config.nix"
        WARNINGS=$((WARNINGS + 1))
      else
        echo "✓ $value found"
      fi
    done
    
    # Check if configs directory exists
    if [ ! -d "$CONFIGS_DIR" ]; then
      echo "INFO: configs/ directory does not exist (optional, but recommended for modular config)"
    else
      echo "✓ configs/ directory exists"
      
      # Find all config.nix files recursively
      CONFIG_FILES=$(find "$CONFIGS_DIR" -name "config.nix" -type f)

      if [ -z "$CONFIG_FILES" ]; then
        echo "INFO: No config.nix files found in configs/ directory"
      else
        NUM_CONFIG_FILES=$(echo "$CONFIG_FILES" | wc -l)
        echo "✓ Found $NUM_CONFIG_FILES config file(s) in configs/ directory"

        # Validate each config file
        echo "$CONFIG_FILES" | while read -r config_file; do
          if [ -f "$config_file" ]; then
            if ${pkgs.nix}/bin/nix-instantiate --parse "$config_file" >/dev/null 2>&1; then
              echo "  ✓ $(basename "$(dirname "$config_file")")/$(basename "$config_file") syntax is valid"
            else
              echo "  ERROR: $(basename "$(dirname "$config_file")")/$(basename "$config_file") has invalid Nix syntax"
              ERRORS=$((ERRORS + 1))
            fi
          fi
        done
      fi
    fi
    
    # Check if old structure exists (should be minimal)
    LINE_COUNT=$(wc -l < "$SYSTEM_CONFIG" 2>/dev/null || echo "0")
    if [ "$LINE_COUNT" -gt 30 ]; then
      echo "WARNING: system-config.nix has more than 30 lines (should be minimal, ~20 lines)"
      echo "         Consider running 'ncc-migrate-config' to migrate to modular structure"
      WARNINGS=$((WARNINGS + 1))
    fi
    
    # Check for non-critical values in system-config.nix (should be in configs/)
    if grep -q "desktop = {" "$SYSTEM_CONFIG" 2>/dev/null || \
       grep -q "hardware = {" "$SYSTEM_CONFIG" 2>/dev/null || \
       grep -q "features = {" "$SYSTEM_CONFIG" 2>/dev/null || \
       grep -q "packageModules = " "$SYSTEM_CONFIG" 2>/dev/null; then
      echo "WARNING: Non-critical values found in system-config.nix"
      echo "         These should be in separate configs/ files"
      echo "         Consider running 'ncc-migrate-config' to migrate to modular structure"
      WARNINGS=$((WARNINGS + 1))
    fi
    
    # Summary
    echo ""
    echo "Validation Summary:"
    if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
      echo "✓ All checks passed!"
      exit 0
    else
      if [ $ERRORS -gt 0 ]; then
        echo "✗ Found $ERRORS error(s)"
      fi
      if [ $WARNINGS -gt 0 ]; then
        echo "⚠ Found $WARNINGS warning(s)"
      fi
      exit 1
    fi
  '';

in {
  inherit validateSystemConfig;
}

