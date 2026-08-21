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
  # --dry-run: validate + preview migrations only (no writes under /etc/nixos).
  # Nested under system-update (default): one [ OK ] line per step; chatter with -v.
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

    if [ -n "''${NCC_CLI_VERBOSE:-}" ]; then
      VERBOSE=true
    fi

    VERBOSE_FLAG=""
    if [ "$VERBOSE" = "true" ]; then
      VERBOSE_FLAG="--verbose"
    fi

    MIGRATE_EXTRA=""
    if [ "$DRY_RUN" = "true" ]; then
      MIGRATE_EXTRA="--dry-run"
    fi

    # Checklist mode: nested + not verbose → badges only
    QUIET=false
    if [ -n "''${NCC_CLI_NESTED:-}" ] && [ "$VERBOSE" != "true" ]; then
      QUIET=true
    fi

    run_module_migrate() {
      local migrate_log
      migrate_log=$(mktemp /tmp/ncc-migrate.XXXXXX.log)
      if command -v ncc-module-migrate >/dev/null 2>&1; then
        if [ "$QUIET" = "true" ]; then
          if NCC_CLI_NESTED=1 ncc-module-migrate $MIGRATE_EXTRA $VERBOSE_FLAG >"$migrate_log" 2>&1; then
            ${formatter.badges.success "Migrations"}
            rm -f "$migrate_log"
            return 0
          else
            cat "$migrate_log"
            rm -f "$migrate_log"
            ${formatter.badges.warning "Migrations"}
            return 1
          fi
        fi
        ${formatter.messages.loading "Checking module config migrations…"}
        if NCC_CLI_NESTED=1 ncc-module-migrate $MIGRATE_EXTRA $VERBOSE_FLAG; then
          ${formatter.badges.success "Migrations"}
        else
          ${formatter.messages.warning "Module migrate had issues — run: sudo ncc modules migrate --verbose"}
          return 1
        fi
      elif command -v ncc >/dev/null 2>&1; then
        if [ "$QUIET" = "true" ]; then
          if NCC_CLI_NESTED=1 ncc modules migrate $MIGRATE_EXTRA $VERBOSE_FLAG >"$migrate_log" 2>&1; then
            ${formatter.badges.success "Migrations"}
            rm -f "$migrate_log"
            return 0
          else
            cat "$migrate_log"
            rm -f "$migrate_log"
            ${formatter.badges.warning "Migrations"}
            return 1
          fi
        fi
        ${formatter.messages.loading "Checking module config migrations…"}
        if NCC_CLI_NESTED=1 ncc modules migrate $MIGRATE_EXTRA $VERBOSE_FLAG; then
          ${formatter.badges.success "Migrations"}
        else
          ${formatter.messages.warning "Module migrate had issues — run: sudo ncc modules migrate"}
          return 1
        fi
      else
        if [ "$VERBOSE" = "true" ]; then
          ${formatter.messages.info "ncc-module-migrate not on PATH (skip)"}
        fi
        ${formatter.badges.success "Migrations"}
      fi
      return 0
    }

    if [ "$DRY_RUN" = "true" ]; then
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${formatter.text.header "Config check (dry-run)"}
        ${formatter.messages.info "Preview only — nothing will be written under /etc/nixos"}
      fi
      if [ "$QUIET" = "true" ]; then
        _vlog=$(mktemp /tmp/ncc-validate.XXXXXX.log)
        if ${validator.validateSystemConfig}/bin/ncc-validate-config $VERBOSE_FLAG >"$_vlog" 2>&1; then
          ${formatter.badges.success "Config"}
        else
          cat "$_vlog"
          ${formatter.badges.warning "Config"}
        fi
        rm -f "$_vlog"
      else
        ${formatter.messages.loading "Checking system configuration…"}
        if ${validator.validateSystemConfig}/bin/ncc-validate-config $VERBOSE_FLAG 2>&1; then
          ${formatter.badges.success "Config"}
        else
          ${formatter.badges.warning "Config"}
          if [ "$VERBOSE" = "false" ]; then
            ${formatter.messages.info "Add --verbose for details, or run without --dry-run to migrate"}
          fi
        fi
      fi
      run_module_migrate || true
      ${formatter.badges.success "Dry-run config check"}
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${formatter.messages.info "Next: ncc system update --dry-run --local --source-dir /path/to/NixOSControlCenter/nixos"}
      fi
      exit 0
    fi

    if [ -z "''${NCC_CLI_NESTED:-}" ]; then
      ${formatter.text.header "Config check"}
    fi

    if ! ${legacyCleanup.cleanupLegacyConfigs}/bin/ncc-cleanup-legacy-configs $VERBOSE_FLAG 2>&1; then
      ${formatter.badges.error "Config"}
      ${formatter.messages.info "Next: sudo ncc system migrate-config --verbose"}
      exit 1
    fi

    if [ "$QUIET" = "true" ]; then
      _vlog=$(mktemp /tmp/ncc-validate.XXXXXX.log)
      if ${validator.validateSystemConfig}/bin/ncc-validate-config $VERBOSE_FLAG >"$_vlog" 2>&1; then
        ${formatter.badges.success "Config"}
        rm -f "$_vlog"
        run_module_migrate || true
        exit 0
      else
        VALIDATION_EXIT=$?
        cat "$_vlog"
        rm -f "$_vlog"
      fi
    else
      ${formatter.messages.loading "Checking system configuration…"}
      if ${validator.validateSystemConfig}/bin/ncc-validate-config $VERBOSE_FLAG 2>&1; then
        ${formatter.badges.success "Config"}
        run_module_migrate || true
        if [ -z "''${NCC_CLI_NESTED:-}" ]; then
          ${formatter.messages.info "Next: ncc system update --dry-run --local --source-dir /path/to/NixOSControlCenter/nixos"}
        fi
        exit 0
      else
        VALIDATION_EXIT=$?
      fi
    fi

    if [ "''${VALIDATION_EXIT:-1}" -eq 1 ]; then
      ${formatter.badges.warning "Config"}
      ${formatter.messages.info "Attempting automatic migration…"}

      if ${migration.migrateSystemConfig}/bin/ncc-migrate-config $VERBOSE_FLAG 2>&1; then
        ${formatter.badges.success "Config migrated"}
        ${legacyCleanup.cleanupLegacyConfigs}/bin/ncc-cleanup-legacy-configs $VERBOSE_FLAG 2>&1 || true

        if ${validator.validateSystemConfig}/bin/ncc-validate-config $VERBOSE_FLAG 2>&1; then
          ${formatter.badges.success "Config"}
          run_module_migrate || true
          if [ -z "''${NCC_CLI_NESTED:-}" ]; then
            ${formatter.messages.info "Next: sudo ncc system build switch"}
          fi
          exit 0
        else
          ${formatter.badges.error "Config"}
          ${formatter.messages.info "Next: ncc-config-check --verbose"}
          exit 1
        fi
      else
        ${formatter.badges.error "Config"}
        ${formatter.messages.info "Next: ncc-config-check --verbose"}
        exit 1
      fi
    else
      ${formatter.badges.error "Config"}
      ${formatter.messages.info "Next: ncc-config-check --verbose"}
      exit 1
    fi
  '';
}
