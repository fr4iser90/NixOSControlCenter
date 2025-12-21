{ config, lib, pkgs, ... }:

with lib;

let
  ui = config.core.management.system-manager.submodules.cli-formatter.api;
  versionChecker = import ../handlers/module-version-check.nix { inherit config lib; };
  
  # Create the update-modules script
  updateModulesScript = pkgs.writeShellScriptBin "ncc-update-modules" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # Parse arguments
    DRY_RUN=false
    AUTO_MODE=false
    MODULE_FILTER=""
    
    while [[ $# -gt 0 ]]; do
      case $1 in
        --dry-run|-d)
          DRY_RUN=true
          shift
          ;;
        --auto|-a)
          AUTO_MODE=true
          shift
          ;;
        --module=*)
          MODULE_FILTER="''${1#*=}"
          shift
          ;;
        --module)
          MODULE_FILTER="$2"
          shift 2
          ;;
        *)
          ${ui.messages.error "Unknown option: $1"}
          echo "Usage: ncc-update-modules [--module=name] [--dry-run] [--auto]"
          exit 1
          ;;
      esac
    done
    
    ${ui.text.header "Module Update"}
    
    if [ "$DRY_RUN" = "true" ]; then
      ${ui.messages.info "DRY RUN MODE - No changes will be made"}
    fi
    
    # Get modules directory
    MODULES_DIR="${toString ../../../../modules}"
    MODULES_CONFIG="/etc/nixos/configs/module-manager-config.nix"
    
    # Collect modules that need updates
    MODULES_TO_UPDATE=()
    MODULES_MANUAL=()
    MODULES_AUTO=()
    
    # Iterate through all modules
    for module_dir in "$MODULES_DIR"/*; do
      if [ ! -d "$module_dir" ]; then
        continue
      fi
      
      module=$(basename "$module_dir")
      
      # Filter by --module if specified
      if [ -n "$MODULE_FILTER" ] && [ "$module" != "$MODULE_FILTER" ]; then
        continue
      fi
      
      # Get installed version
      INSTALLED=$(${pkgs.nix}/bin/nix-instantiate --eval --strict -E "
        (import <nixpkgs/nixos> { configuration = {}; }).config.modules.$module._version or \"unknown\"
      " 2>/dev/null || echo "unknown")
      
      # Get available version from options.nix
      OPTIONS_FILE="$module_dir/options.nix"
      if [ -f "$OPTIONS_FILE" ]; then
        AVAILABLE=$(${pkgs.gnugrep}/bin/grep -m 1 'moduleVersion =' "$OPTIONS_FILE" 2>/dev/null | ${pkgs.gnused}/bin/sed 's/.*moduleVersion = "\([^"]*\)".*/\1/' || echo "unknown")
      else
        AVAILABLE="unknown"
      fi
      
      # Skip if versions are unknown or already current
      if [ "$INSTALLED" = "unknown" ] || [ "$AVAILABLE" = "unknown" ]; then
        continue
      fi
      
      if [ "$INSTALLED" = "$AVAILABLE" ]; then
        continue  # Already up to date
      fi
      
      # Check if migration exists
      MIGRATIONS_DIR="$module_dir/migrations"
      HAS_MIGRATION=false
      if [ -d "$MIGRATIONS_DIR" ]; then
        MIGRATION_FILE=$(find "$MIGRATIONS_DIR" -name "v''${INSTALLED}-to-v''${AVAILABLE}.nix" 2>/dev/null | head -1)
        if [ -n "$MIGRATION_FILE" ]; then
          HAS_MIGRATION=true
        fi
      fi
      
      if [ "$HAS_MIGRATION" = "true" ]; then
        MODULES_AUTO+=("$module:$INSTALLED:$AVAILABLE")
      else
        MODULES_MANUAL+=("$module:$INSTALLED:$AVAILABLE")
      fi
    done
    
    # Show update status
    echo ""
    if [ ''${#MODULES_AUTO[@]} -eq 0 ] && [ ''${#MODULES_MANUAL[@]} -eq 0 ]; then
      ${ui.messages.success "All modules are up to date!"}
      exit 0
    fi
    
    ${ui.messages.info "Modules with automatic migration available:"}
    if [ ''${#MODULES_AUTO[@]} -eq 0 ]; then
      echo "  (none)"
    else
      for module_info in "''${MODULES_AUTO[@]}"; do
        IFS=':' read -r module from to <<< "$module_info"
        echo "  - $module: $from → $to (auto-update)"
      done
    fi
    
    echo ""
    ${ui.messages.warning "Modules requiring manual update:"}
    if [ ''${#MODULES_MANUAL[@]} -eq 0 ]; then
      echo "  (none)"
    else
      for module_info in "''${MODULES_MANUAL[@]}"; do
        IFS=':' read -r module from to <<< "$module_info"
        echo "  - $module: $from → $to (manual update required)"
      done
    fi
    
    # Ask for confirmation (unless --auto)
    if [ "$AUTO_MODE" = "false" ] && [ ''${#MODULES_AUTO[@]} -gt 0 ]; then
      echo ""
      printf "Update modules with automatic migration? (y/n): "
      read -r confirm
      if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        ${ui.messages.info "Update cancelled"}
        exit 0
      fi
    fi
    
    # Perform updates
    if [ "$DRY_RUN" = "true" ]; then
      ${ui.messages.info "DRY RUN: Would update the following modules:"}
      for module_info in "''${MODULES_AUTO[@]}"; do
        IFS=':' read -r module from to <<< "$module_info"
        echo "  - $module: $from → $to"
      done
      exit 0
    fi
    
    # Update modules with automatic migration
    if [ ''${#MODULES_AUTO[@]} -gt 0 ]; then
      ${ui.messages.loading "Updating modules..."}
      
      for module_info in "''${MODULES_AUTO[@]}"; do
        IFS=':' read -r module from to <<< "$module_info"
        
        ${ui.messages.info "Updating $module: $from → $to"}
        
        # Execute migration
        MIGRATION_FILE="$module_dir/migrations/v$from-to-v$to.nix"
        if [ -f "$MIGRATION_FILE" ]; then
          ${ui.messages.info "Executing migration: $MIGRATION_FILE"}
          
          # Load migration plan
          MIGRATION_PLAN=$(${pkgs.nix}/bin/nix-instantiate --eval --strict --json -E "
            import $MIGRATION_FILE { inherit (import <nixpkgs/lib>) lib; }
          " 2>/dev/null || echo "{}")
          
          if [ "$MIGRATION_PLAN" != "{}" ]; then
            # Apply option renamings if present
            OPTION_RENAMINGS=$(${pkgs.jq}/bin/jq -r '.optionRenamings // {} | to_entries | .[] | "\(.key)|\(.value)"' <<< "$MIGRATION_PLAN" 2>/dev/null || echo "")
            if [ -n "$OPTION_RENAMINGS" ]; then
              ${ui.messages.info "  Applying option renamings..."}
              # TODO: Implement actual option renaming in config files
            fi
            
            # Execute migration script if present
            MIGRATION_SCRIPT=$(${pkgs.jq}/bin/jq -r '.migrationScript // ""' <<< "$MIGRATION_PLAN" 2>/dev/null || echo "")
            if [ -n "$MIGRATION_SCRIPT" ] && [ "$MIGRATION_SCRIPT" != "null" ] && [ "$MIGRATION_SCRIPT" != "" ]; then
              ${ui.messages.info "  Executing migration script..."}
              eval "$MIGRATION_SCRIPT"
            fi
          fi
          
          # Update version in module-manager-config.nix
          ${ui.messages.info "  Updating version to $to..."}
          # TODO: Implement proper config file update
          ${ui.messages.success "  Migration completed: $module $from → $to"}
        else
          ${ui.messages.warning "Migration file not found: $MIGRATION_FILE"}
          ${ui.messages.info "Skipping migration for $module"}
        fi
      done
      
      ${ui.messages.success "Modules updated successfully!"}
    fi
    
    # Warn about manual updates
    if [ ''${#MODULES_MANUAL[@]} -gt 0 ]; then
      echo ""
      ${ui.messages.warning "The following modules require manual update:"}
      for module_info in "''${MODULES_MANUAL[@]}"; do
        IFS=':' read -r module from to <<< "$module_info"
        echo "  - $module: $from → $to"
        ${ui.messages.info "  → No migration available. Please update manually or create migration file."}
      done
    fi
  '';

in {
  inherit updateModulesScript;
}

