{ pkgs, lib, getModuleApi, ... }:

let
  schema = import ./schema.nix { inherit lib; };
  detection = import ./detection.nix { inherit pkgs lib; };
  formatter = getModuleApi "cli-formatter";
  facade = import ../../lib/config-facade.nix { inherit pkgs; };
  currentVersion = schema.currentVersion;
  supportedVersions = lib.attrNames schema.schemas;

  requiredFieldsMap = lib.mapAttrs (version: schema: schema.requiredFields) schema.schemas;
  requiredFieldsJson = builtins.toJSON requiredFieldsMap;

  structureInfoMap = lib.mapAttrs (version: schema:
    schema.structure or {}
  ) schema.schemas;
  structureInfoJson = builtins.toJSON structureInfoMap;

  expectedConfigFilesMap = lib.mapAttrs (version: schema:
    schema.expectedConfigFiles or []
  ) schema.schemas;
  expectedConfigFilesJson = builtins.toJSON expectedConfigFilesMap;

  # Validation — layout/paths ONLY via config-facade (ncc_detect_layout / MONOLITH_FILE / CONFIGS_BASE)
  validateSystemConfig = pkgs.writeShellScriptBin "ncc-validate-config" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    VERBOSE=false
    for arg in "$@"; do
      case "$arg" in
        --verbose|--debug|-v)
          VERBOSE=true
          ;;
      esac
    done

    ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}

    # Legacy v0 only (pre-v1 flat file) — not part of facade layout
    SYSTEM_CONFIG_LEGACY="/etc/nixos/system-config.nix"

    ERRORS=0
    WARNINGS=0

    if ! ncc_config_present && [ ! -f "$SYSTEM_CONFIG_LEGACY" ]; then
      ${formatter.messages.error "No configuration found"}
      ${formatter.messages.info "Expected monolith: $MONOLITH_FILE"}
      ${formatter.messages.info "Or split leaves under: $CONFIGS_BASE/**/config.nix"}
      exit 1
    fi

    LAYOUT=$(ncc_detect_layout)
    if [ "$VERBOSE" = "true" ]; then
      ${formatter.messages.info "Layout: $LAYOUT"}
      case "$LAYOUT" in
        monolith) ${formatter.messages.info "SSOT: $MONOLITH_FILE"} ;;
        split) ${formatter.messages.info "SSOT: $CONFIGS_BASE/**/config.nix"} ;;
      esac
    fi

    # Syntax-check the active SSOT
    case "$LAYOUT" in
      monolith)
        if [ -f "$MONOLITH_FILE" ]; then
          if ! ${pkgs.nix}/bin/nix-instantiate --parse "$MONOLITH_FILE" >/dev/null 2>&1; then
            ${formatter.messages.error "systemConfig.nix has invalid Nix syntax"}
            ERRORS=$((ERRORS + 1))
          elif [ "$VERBOSE" = "true" ]; then
            ${formatter.messages.success "Monolith Nix syntax is valid"}
          fi
        fi
        ;;
      split)
        if [ "$VERBOSE" = "true" ]; then
          ${formatter.messages.info "Validating split systemConfig/ leaves..."}
        fi
        ;;
    esac

    if [ -f "$SYSTEM_CONFIG_LEGACY" ] && [ "$VERBOSE" = "true" ]; then
      ${formatter.messages.info "Legacy system-config.nix still present (v0)"}
      if ! ${pkgs.nix}/bin/nix-instantiate --parse "$SYSTEM_CONFIG_LEGACY" >/dev/null 2>&1; then
        ${formatter.messages.error "system-config.nix has invalid Nix syntax"}
        ERRORS=$((ERRORS + 1))
      fi
    fi

    CONFIG_VERSION=''$(${detection.detectConfigVersion}/bin/ncc-detect-version)
    CURRENT_VERSION="${currentVersion}"
    SUPPORTED_VERSIONS="${toString supportedVersions}"
    REQUIRED_FIELDS_MAP='${requiredFieldsJson}'
    STRUCTURE_INFO_MAP='${structureInfoJson}'
    EXPECTED_CONFIG_FILES_MAP='${expectedConfigFilesJson}'

    if [ "$VERBOSE" = "true" ]; then
      ${formatter.messages.success "Detected config version: $CONFIG_VERSION"}
      ${formatter.messages.success "Current supported version: $CURRENT_VERSION"}
      ${formatter.messages.info "Supported versions: $SUPPORTED_VERSIONS"}
    fi

    VERSION_SUPPORTED=false
    for v in $SUPPORTED_VERSIONS; do
      if [ "$v" = "$CONFIG_VERSION" ]; then
        VERSION_SUPPORTED=true
        break
      fi
    done

    if [ "$VERSION_SUPPORTED" = "false" ]; then
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.messages.warning "Config version $CONFIG_VERSION not recognized (assuming v0)"}
      fi
      CONFIG_VERSION="1.0"
    fi

    if [ "$CONFIG_VERSION" != "$CURRENT_VERSION" ]; then
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.messages.warning "Config version $CONFIG_VERSION does not match current version $CURRENT_VERSION"}
        ${formatter.messages.info "Migration needed - this will be handled automatically"}
      fi
      ERRORS=$((ERRORS + 1))
    fi

    REQUIRED_FIELDS=$(echo "$REQUIRED_FIELDS_MAP" | ${pkgs.jq}/bin/jq -r ".\"$CONFIG_VERSION\" // [] | .[]")
    for field in $REQUIRED_FIELDS; do
      FOUND=false
      case "$LAYOUT" in
        monolith)
          if [ -f "$MONOLITH_FILE" ]; then
            if ${pkgs.nix}/bin/nix-instantiate --eval --strict -E \
              "(import $MONOLITH_FILE).core.management.\"system-manager\".$field or (import $MONOLITH_FILE).$field or null" \
              2>/dev/null | grep -qv '^null$'; then
              FOUND=true
            fi
          fi
          ;;
        split)
          CHECK_CONFIG="$CONFIGS_BASE/core/management/system-manager/config.nix"
          if [ -f "$CHECK_CONFIG" ]; then
            if ${pkgs.nix}/bin/nix-instantiate --eval --strict -E \
              "(import $CHECK_CONFIG).$field or null" 2>/dev/null | grep -qv '^null$'; then
              FOUND=true
            fi
          fi
          ;;
      esac
      if [ "$FOUND" = "false" ] && [ -f "$SYSTEM_CONFIG_LEGACY" ]; then
        if ${pkgs.nix}/bin/nix-instantiate --eval --strict -E \
          "(import $SYSTEM_CONFIG_LEGACY).$field or null" 2>/dev/null | grep -qv '^null$'; then
          FOUND=true
        fi
      fi
      if [ "$FOUND" = "true" ]; then
        if [ "$VERBOSE" = "true" ]; then
          ${formatter.messages.success "$field found"}
        fi
      else
        if [ "$VERBOSE" = "true" ]; then
          ${formatter.messages.warning "Required field '$field' not found (v$CONFIG_VERSION)"}
        fi
        WARNINGS=$((WARNINGS + 1))
      fi
    done

    STRUCTURE_INFO=$(echo "$STRUCTURE_INFO_MAP" | ${pkgs.jq}/bin/jq -r ".\"$CONFIG_VERSION\" // {}")
    MAX_LINES=$(echo "$STRUCTURE_INFO" | ${pkgs.jq}/bin/jq -r '.maxSystemConfigLines // 9999')
    FORBIDDEN_FIELDS=$(echo "$STRUCTURE_INFO" | ${pkgs.jq}/bin/jq -r '.forbiddenInSystemConfig // [] | .[]')

    if [ -f "$SYSTEM_CONFIG_LEGACY" ]; then
      if [ "$MAX_LINES" -lt 9999 ]; then
        LINE_COUNT=$(wc -l < "$SYSTEM_CONFIG_LEGACY" 2>/dev/null || echo "0")
        if [ "$LINE_COUNT" -gt "$MAX_LINES" ]; then
          if [ "$VERBOSE" = "true" ]; then
            ${formatter.messages.warning "system-config.nix has more than $MAX_LINES lines (should be minimal for v$CONFIG_VERSION)"}
            ${formatter.messages.info "Consider running 'ncc-migrate-config' to migrate to modular structure"}
          fi
          WARNINGS=$((WARNINGS + 1))
        fi
      fi

      for field in $FORBIDDEN_FIELDS; do
        if grep -q "$field = {" "$SYSTEM_CONFIG_LEGACY" 2>/dev/null || \
           grep -q "$field = " "$SYSTEM_CONFIG_LEGACY" 2>/dev/null; then
          if [ "$VERBOSE" = "true" ]; then
            ${formatter.messages.warning "Non-critical field '$field' found in system-config.nix (v$CONFIG_VERSION)"}
            ${formatter.messages.info "This should be in separate systemConfig/ files"}
            ${formatter.messages.info "Consider running 'ncc-migrate-config' to migrate to modular structure"}
          fi
          WARNINGS=$((WARNINGS + 1))
        fi
      done
    fi

    LEGACY_CONFIGS_DIR="/etc/nixos/configs"
    if [ -d "$LEGACY_CONFIGS_DIR" ]; then
      ${formatter.messages.error "Legacy configs/ directory still exists (must be cleaned)"}
      ${formatter.messages.info "Run: ncc-cleanup-legacy-configs  (or ncc-config-check / system-update)"}
      ERRORS=$((ERRORS + 1))
    fi

    # Split only: validate leaves. Monolith must NOT require systemConfig/**/config.nix
    if [ "$LAYOUT" = "split" ] && [ -d "$CONFIGS_BASE" ]; then
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.messages.success "systemConfig/ directory exists"}
      fi
      while IFS= read -r config_file; do
        CONFIG_BASENAME=$(echo "$config_file" | sed "s|$CONFIGS_BASE/||")
        case "$CONFIG_BASENAME" in
          core/config.nix|core/base/config.nix|core/management/config.nix|modules/config.nix|modules/infrastructure/config.nix|modules/security/config.nix|modules/specialized/config.nix|modules/system/config.nix)
            if [ "$VERBOSE" = "true" ]; then
              ${formatter.messages.info "  $CONFIG_BASENAME (aggregator, skipped)"}
            fi
            continue
            ;;
        esac
        if ${pkgs.nix}/bin/nix-instantiate --parse "$config_file" >/dev/null 2>&1; then
          if [ "$VERBOSE" = "true" ]; then
            ${formatter.messages.success "  $CONFIG_BASENAME syntax is valid"}
          fi
        else
          ${formatter.messages.error "  $CONFIG_BASENAME has invalid Nix syntax"}
          ERRORS=$((ERRORS + 1))
        fi
      done < <(find "$CONFIGS_BASE" -name "config.nix" -type f 2>/dev/null)
    fi

    if [ "$CONFIG_VERSION" = "1.0" ] && [ "$CONFIG_VERSION" != "$CURRENT_VERSION" ]; then
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.messages.info "v0 structure detected (monolithic)"}
        ${formatter.messages.info "Consider running 'ncc-migrate-config' to migrate to v$CURRENT_VERSION (modular structure)"}
      fi
    fi

    if [ "$VERBOSE" = "true" ]; then
      ${formatter.text.newline}
      ${formatter.text.section "Validation Summary"}
    fi
    if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.messages.success "All checks passed!"}
      fi
      exit 0
    else
      if [ $ERRORS -gt 0 ]; then
        ${formatter.messages.error "Found $ERRORS error(s)"}
        if [ "$VERBOSE" = "false" ]; then
          ${formatter.messages.info "Run with --verbose to see details"}
        fi
      fi
      if [ $WARNINGS -gt 0 ]; then
        if [ "$VERBOSE" = "true" ]; then
          ${formatter.messages.warning "Found $WARNINGS warning(s)"}
        fi
      fi
      exit 1
    fi
  '';

in {
  inherit validateSystemConfig;
}
