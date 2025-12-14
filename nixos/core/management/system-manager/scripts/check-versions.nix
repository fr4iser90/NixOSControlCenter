{ config, lib, pkgs, ... }:

with lib;

let
  ui = config.core.management.system-manager.submodules.cli-formatter.api;
  versionChecker = import ../handlers/module-version-check.nix { inherit config lib; };
  
  # Create the check-versions script
  checkVersionsScript = pkgs.writeShellScriptBin "ncc-check-module-versions" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    ${ui.text.header "Module Version Check"}
    ${ui.messages.info "Checking module versions (Core + Features)..."}
    
    # Get module directories
    CORE_DIR="${toString ../../../../core}"
    FEATURES_DIR="${toString ../../../../features}"
    
    echo ""
    echo "=== Core Modules ==="
    printf "%-30s %-15s %-15s %-15s %s\n" "Module" "Installed" "Available" "Stable" "Status"
    echo "--------------------------------------------------------------------------------"
    
    # Iterate through all core modules
    for module_dir in "$CORE_DIR"/*; do
      if [ ! -d "$module_dir" ]; then
        continue
      fi
      
      module=$(basename "$module_dir")
      
      # Skip system-manager (it's the manager itself)
      if [ "$module" = "system-manager" ]; then
        continue
      fi
      
      # Get installed version from config
      INSTALLED=$(${pkgs.nix}/bin/nix-instantiate --eval --strict -E "
        (import <nixpkgs/nixos> { configuration = {}; }).config.systemConfig.$module._version or \"unknown\"
      " 2>/dev/null || echo "unknown")
      
      # Get available version from options.nix
      OPTIONS_FILE="$module_dir/options.nix"
      if [ -f "$OPTIONS_FILE" ]; then
        # Extract moduleVersion from options.nix
        AVAILABLE=$(${pkgs.gnugrep}/bin/grep -m 1 'moduleVersion =' "$OPTIONS_FILE" 2>/dev/null | ${pkgs.gnused}/bin/sed 's/.*moduleVersion = "\([^"]*\)".*/\1/' || echo "unknown")
        
        # Extract stableVersion (optional)
        if ${pkgs.gnugrep}/bin/grep -q 'stableVersion =' "$OPTIONS_FILE" 2>/dev/null; then
          STABLE=$(${pkgs.gnugrep}/bin/grep -m 1 'stableVersion =' "$OPTIONS_FILE" 2>/dev/null | ${pkgs.gnused}/bin/sed 's/.*stableVersion = "\([^"]*\)".*/\1/' || echo "$AVAILABLE")
        else
          STABLE="$AVAILABLE"
        fi
      else
        AVAILABLE="unknown"
        STABLE="unknown"
      fi
      
      # Determine status
      if [ "$INSTALLED" = "unknown" ] || [ "$AVAILABLE" = "unknown" ]; then
        STATUS_SYMBOL="❓"
        STATUS_TEXT="unknown"
      elif [ "$INSTALLED" = "$AVAILABLE" ]; then
        STATUS_SYMBOL="✅"
        STATUS_TEXT="current"
      else
        # Check if migration exists
        MIGRATIONS_DIR="$module_dir/migrations"
        if [ -d "$MIGRATIONS_DIR" ]; then
          MIGRATION_FILE=$(find "$MIGRATIONS_DIR" -name "v''${INSTALLED}-to-v''${AVAILABLE}.nix" 2>/dev/null | head -1)
          if [ -n "$MIGRATION_FILE" ]; then
            STATUS_SYMBOL="🔄"
            STATUS_TEXT="auto-update"
          else
            STATUS_SYMBOL="⚠️"
            STATUS_TEXT="manual-update"
          fi
        else
          STATUS_SYMBOL="⚠️"
          STATUS_TEXT="manual-update"
        fi
      fi
      
      # Format stable version display
      if [ "$STABLE" != "$AVAILABLE" ] && [ "$STABLE" != "unknown" ]; then
        STABLE_DISPLAY="$STABLE"
      else
        STABLE_DISPLAY="-"
      fi
      
      printf "%-30s %-15s %-15s %-15s %s %s\n" "$module" "$INSTALLED" "$AVAILABLE" "$STABLE_DISPLAY" "$STATUS_SYMBOL" "$STATUS_TEXT"
    done
    
    echo ""
    echo "=== Feature Modules ==="
    printf "%-30s %-15s %-15s %-15s %s\n" "Feature" "Installed" "Available" "Stable" "Status"
    echo "--------------------------------------------------------------------------------"
    
    # Iterate through all features
    for feature_dir in "$FEATURES_DIR"/*; do
      if [ ! -d "$feature_dir" ]; then
        continue
      fi
      
      feature=$(basename "$feature_dir")
      
      # Get installed version from config
      INSTALLED=$(${pkgs.nix}/bin/nix-instantiate --eval --strict -E "
        (import <nixpkgs/nixos> { configuration = {}; }).config.features.$feature._version or \"unknown\"
      " 2>/dev/null || echo "unknown")
      
      # Get available version from options.nix
      OPTIONS_FILE="$feature_dir/options.nix"
      if [ -f "$OPTIONS_FILE" ]; then
        # Extract moduleVersion from options.nix
        AVAILABLE=$(${pkgs.gnugrep}/bin/grep -m 1 'moduleVersion =' "$OPTIONS_FILE" 2>/dev/null | ${pkgs.gnused}/bin/sed 's/.*moduleVersion = "\([^"]*\)".*/\1/' || echo "unknown")
        
        # Extract stableVersion (optional)
        if ${pkgs.gnugrep}/bin/grep -q 'stableVersion =' "$OPTIONS_FILE" 2>/dev/null; then
          STABLE=$(${pkgs.gnugrep}/bin/grep -m 1 'stableVersion =' "$OPTIONS_FILE" 2>/dev/null | ${pkgs.gnused}/bin/sed 's/.*stableVersion = "\([^"]*\)".*/\1/' || echo "$AVAILABLE")
        else
          STABLE="$AVAILABLE"
        fi
      else
        AVAILABLE="unknown"
        STABLE="unknown"
      fi
      
      # Determine status
      if [ "$INSTALLED" = "unknown" ] || [ "$AVAILABLE" = "unknown" ]; then
        STATUS_SYMBOL="❓"
        STATUS_TEXT="unknown"
      elif [ "$INSTALLED" = "$AVAILABLE" ]; then
        STATUS_SYMBOL="✅"
        STATUS_TEXT="current"
      else
        # Check if migration exists
        MIGRATIONS_DIR="$feature_dir/migrations"
        if [ -d "$MIGRATIONS_DIR" ]; then
          MIGRATION_FILE=$(find "$MIGRATIONS_DIR" -name "v''${INSTALLED}-to-v''${AVAILABLE}.nix" 2>/dev/null | head -1)
          if [ -n "$MIGRATION_FILE" ]; then
            STATUS_SYMBOL="🔄"
            STATUS_TEXT="auto-update"
          else
            STATUS_SYMBOL="⚠️"
            STATUS_TEXT="manual-update"
          fi
        else
          STATUS_SYMBOL="⚠️"
          STATUS_TEXT="manual-update"
        fi
      fi
      
      # Format stable version display
      if [ "$STABLE" != "$AVAILABLE" ] && [ "$STABLE" != "unknown" ]; then
        STABLE_DISPLAY="$STABLE"
      else
        STABLE_DISPLAY="-"
      fi
      
      printf "%-30s %-15s %-15s %-15s %s %s\n" "$feature" "$INSTALLED" "$AVAILABLE" "$STABLE_DISPLAY" "$STATUS_SYMBOL" "$STATUS_TEXT"
    done
    
    echo ""
    ${ui.messages.info "Use 'ncc update-modules' to update modules (coming soon)"}
  '';

in {
  inherit checkVersionsScript;
}
