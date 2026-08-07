{ config, lib, pkgs, systemConfig, getModuleApi, configPath, ... }:

let
  cfg = systemConfig.${configPath};
  backupHelpers = import ../../lib/backup-helpers.nix { inherit pkgs lib; };
  formatter = getModuleApi "cli-formatter";
  migration = import ./migration.nix { inherit pkgs lib getModuleApi backupHelpers; };
  validator = import ./validator.nix { inherit pkgs lib getModuleApi; };
  legacyCleanup = import ./legacy-cleanup.nix { inherit pkgs lib getModuleApi backupHelpers; };
in

{
  # Main command: ncc-config-check
  # Cleans legacy paths, validates config, migrates if needed, re-validates
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
    
    VERBOSE_FLAG=""
    if [ "$VERBOSE" = "true" ]; then
      VERBOSE_FLAG="--verbose"
    fi

    # Step 0: Always purge leftover pre-v1 paths (configs/ → systemConfig/)
    # Flake only loads systemConfig/; leaving configs/ causes silent wrong edits.
    if ! ${legacyCleanup.cleanupLegacyConfigs}/bin/ncc-cleanup-legacy-configs $VERBOSE_FLAG 2>&1; then
      ${formatter.messages.error "Legacy config cleanup failed"}
      exit 1
    fi
    
    # Step 1: Validate config
    ${formatter.messages.loading "Checking system configuration..."}
    if ${validator.validateSystemConfig}/bin/ncc-validate-config $VERBOSE_FLAG 2>&1; then
      ${formatter.messages.success "Configuration is valid"}
      exit 0
    else
      VALIDATION_EXIT=$?
      if [ $VALIDATION_EXIT -eq 1 ]; then
        ${formatter.messages.warning "Configuration version outdated or has issues"}
        ${formatter.messages.info "Attempting automatic migration..."}
        
        # Step 2: Try migration
        if ${migration.migrateSystemConfig}/bin/ncc-migrate-config $VERBOSE_FLAG 2>&1; then
          ${formatter.messages.success "Migration completed successfully"}

          # Re-run legacy cleanup after migration (migration may recreate nothing,
          # but keeps the invariant: never leave configs/ behind)
          ${legacyCleanup.cleanupLegacyConfigs}/bin/ncc-cleanup-legacy-configs $VERBOSE_FLAG 2>&1 || true
          
          # Step 3: Re-validate after migration
          if [ "$VERBOSE" = "true" ]; then
            ${formatter.messages.loading "Re-validating configuration..."}
          fi
          if ${validator.validateSystemConfig}/bin/ncc-validate-config $VERBOSE_FLAG 2>&1; then
            ${formatter.messages.success "Configuration is now valid"}
            exit 0
          else
            ${formatter.messages.error "Configuration still has issues after migration"}
            ${formatter.messages.info "Manual intervention may be required"}
            if [ "$VERBOSE" = "false" ]; then
              ${formatter.messages.info "Run with --verbose to see detailed error messages"}
            fi
            exit 1
          fi
        else
          ${formatter.messages.error "Migration failed or not needed"}
          ${formatter.messages.info "Configuration may need manual fixes"}
          if [ "$VERBOSE" = "false" ]; then
            ${formatter.messages.info "Run with --verbose to see detailed error messages"}
          fi
          exit 1
        fi
      else
        # Validation failed with unexpected error
        ${formatter.messages.error "Configuration validation failed"}
        if [ "$VERBOSE" = "false" ]; then
          ${formatter.messages.info "Run with --verbose to see detailed error messages"}
        fi
        exit 1
      fi
    fi
  '';
}
