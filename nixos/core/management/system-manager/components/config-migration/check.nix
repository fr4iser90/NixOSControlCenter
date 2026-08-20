{ config, lib, pkgs, systemConfig, getModuleApi, configPath, ... }:

let
  # Nested read from discovery configPath — never systemConfig.${configPath}
  cfg = lib.attrByPath (lib.splitString "." configPath) {} systemConfig;
  backupHelpers = import ../../lib/backup-helpers.nix { inherit pkgs lib; };
  formatter = getModuleApi "cli-formatter";
  migration = import ./migration.nix { inherit pkgs lib getModuleApi backupHelpers; };
  validator = import ./validator.nix { inherit pkgs lib getModuleApi; };
  legacyCleanup = import ./legacy-cleanup.nix { inherit pkgs lib getModuleApi backupHelpers; };
in

{
  # Main command: ncc-config-check
  # Cleans legacy paths, validates config, migrates if needed, re-validates,
  # then runs module migration (renames/merges/orphan cleanup) when available.
  # --dry-run: validate + preview migrations only (no writes under /etc/nixos).
  configCheck = pkgs.writeShellScriptBin "ncc-config-check" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    VERBOSE=false
    DRY_RUN=false
    for arg in "$@"; do
      case "$arg" in
        --verbose|--debug|-v)
          VERBOSE=true
          ;;
        --dry-run|-d)
          DRY_RUN=true
          ;;
      esac
    done

    VERBOSE_FLAG=""
    if [ "$VERBOSE" = "true" ]; then
      VERBOSE_FLAG="--verbose"
    fi

    MIGRATE_EXTRA=""
    if [ "$DRY_RUN" = "true" ]; then
      MIGRATE_EXTRA="--dry-run"
    fi

    run_module_migrate() {
      ${formatter.messages.loading "Checking module config migrations…"}
      if command -v ncc-module-migrate >/dev/null 2>&1; then
        if ncc-module-migrate $MIGRATE_EXTRA $VERBOSE_FLAG; then
          ${formatter.messages.success "Module configs OK"}
        else
          ${formatter.messages.warning "Module migrate had issues — run: sudo ncc modules migrate --verbose"}
          return 1
        fi
      elif command -v ncc >/dev/null 2>&1; then
        if ncc modules migrate $MIGRATE_EXTRA $VERBOSE_FLAG; then
          ${formatter.messages.success "Module configs OK"}
        else
          ${formatter.messages.warning "Module migrate had issues — run: sudo ncc modules migrate"}
          return 1
        fi
      else
        if [ "$VERBOSE" = "true" ]; then
          ${formatter.messages.info "ncc-module-migrate not on PATH (skip)"}
        fi
      fi
      return 0
    }

    if [ "$DRY_RUN" = "true" ]; then
      ${formatter.text.header "Config check (dry-run)"}
      ${formatter.messages.info "Read-only — nothing will be written under /etc/nixos"}
      ${formatter.messages.loading "Checking system configuration…"}
      if ${validator.validateSystemConfig}/bin/ncc-validate-config $VERBOSE_FLAG 2>&1; then
        ${formatter.messages.success "Configuration is valid"}
      else
        ${formatter.messages.warning "Configuration has issues (not fixing in dry-run)"}
        if [ "$VERBOSE" = "false" ]; then
          ${formatter.messages.info "Add --verbose for details, or run without --dry-run to migrate"}
        fi
      fi
      run_module_migrate || true
      ${formatter.messages.success "Dry-run config check finished"}
      exit 0
    fi

    # Step 0: Always purge leftover pre-v1 paths (configs/ → systemConfig/)
    # Flake only loads systemConfig/; leaving configs/ causes silent wrong edits.
    if ! ${legacyCleanup.cleanupLegacyConfigs}/bin/ncc-cleanup-legacy-configs $VERBOSE_FLAG 2>&1; then
      ${formatter.messages.error "Legacy config cleanup failed"}
      exit 1
    fi

    # Step 1: Validate config
    ${formatter.messages.loading "Checking system configuration…"}
    if ${validator.validateSystemConfig}/bin/ncc-validate-config $VERBOSE_FLAG 2>&1; then
      ${formatter.messages.success "Configuration is valid"}
      # Still run module migrate (SSH merge / orphans) even when schema is current
      run_module_migrate || true
      exit 0
    else
      VALIDATION_EXIT=$?
      if [ $VALIDATION_EXIT -eq 1 ]; then
        ${formatter.messages.warning "Configuration version outdated or has issues"}
        ${formatter.messages.info "Attempting automatic migration…"}

        # Step 2: Try migration (also heals missing system.platform on v2.1)
        if ${migration.migrateSystemConfig}/bin/ncc-migrate-config $VERBOSE_FLAG 2>&1; then
          ${formatter.messages.success "Migration completed successfully"}

          # Re-run legacy cleanup after migration (migration may recreate nothing,
          # but keeps the invariant: never leave configs/ behind)
          ${legacyCleanup.cleanupLegacyConfigs}/bin/ncc-cleanup-legacy-configs $VERBOSE_FLAG 2>&1 || true

          # Step 3: Re-validate after migration
          if [ "$VERBOSE" = "true" ]; then
            ${formatter.messages.loading "Re-validating configuration…"}
          fi
          if ${validator.validateSystemConfig}/bin/ncc-validate-config $VERBOSE_FLAG 2>&1; then
            ${formatter.messages.success "Configuration is now valid"}
            run_module_migrate || true
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
