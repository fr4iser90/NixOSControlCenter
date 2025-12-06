{ pkgs, lib, ui, ... }:

let
  migration = import ./config-migration.nix { inherit pkgs lib ui; };
  validator = import ./config-validator.nix { inherit pkgs lib ui; };
in

{
  # Main command: ncc-config-check
  # Validates config, attempts migration if needed, re-validates
  configCheck = pkgs.writeShellScriptBin "ncc-config-check" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # Parse arguments for verbose mode
    VERBOSE=false
    for arg in "$@"; do
      case "$arg" in
        --verbose|--debug|-v)
          VERBOSE=true
          ;;
      esac
    done
    
    SYSTEM_CONFIG="/etc/nixos/system-config.nix"
    
    # Step 1: Validate config
    ${ui.messages.loading "Checking system configuration..."}
    if ${validator.validateSystemConfig}/bin/ncc-validate-config $([ "$VERBOSE" = "true" ] && echo "--verbose") 2>&1; then
      ${ui.messages.success "Configuration is valid"}
      exit 0
    else
      VALIDATION_EXIT=$?
      if [ $VALIDATION_EXIT -eq 1 ]; then
        ${ui.messages.warning "Configuration version outdated or has issues"}
        ${ui.messages.info "Attempting automatic migration..."}
        
        # Step 2: Try migration
        if ${migration.migrateSystemConfig}/bin/ncc-migrate-config $([ "$VERBOSE" = "true" ] && echo "--verbose") 2>&1; then
          ${ui.messages.success "Migration completed successfully"}
          
          # Step 3: Re-validate after migration
          if [ "$VERBOSE" = "true" ]; then
            ${ui.messages.loading "Re-validating configuration..."}
          fi
          if ${validator.validateSystemConfig}/bin/ncc-validate-config $([ "$VERBOSE" = "true" ] && echo "--verbose") 2>&1; then
            ${ui.messages.success "Configuration is now valid"}
            exit 0
          else
            ${ui.messages.error "Configuration still has issues after migration"}
            ${ui.messages.info "Manual intervention may be required"}
            if [ "$VERBOSE" = "false" ]; then
              ${ui.messages.info "Run with --verbose to see detailed error messages"}
            fi
            exit 1
          fi
        else
          ${ui.messages.error "Migration failed or not needed"}
          ${ui.messages.info "Configuration may need manual fixes"}
          if [ "$VERBOSE" = "false" ]; then
            ${ui.messages.info "Run with --verbose to see detailed error messages"}
          fi
          exit 1
        fi
      else
        # Validation failed with unexpected error
        ${ui.messages.error "Configuration validation failed"}
        if [ "$VERBOSE" = "false" ]; then
          ${ui.messages.info "Run with --verbose to see detailed error messages"}
        fi
        exit 1
      fi
    fi
  '';
}

