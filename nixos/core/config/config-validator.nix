{ pkgs, lib, formatter, ... }:

let
  schema = import ./config-schema.nix { inherit lib; };
  detection = import ./config-detection.nix { inherit pkgs lib; };
  currentVersion = schema.currentVersion;
  supportedVersions = lib.attrNames schema.schemas;
  
  # Build required fields map per version (for dynamic validation)
  requiredFieldsMap = lib.mapAttrs (version: schema: schema.requiredFields) schema.schemas;
  requiredFieldsJson = builtins.toJSON requiredFieldsMap;
  
  # Build structure info per version (for dynamic validation)
  structureInfoMap = lib.mapAttrs (version: schema: 
    schema.structure or {}
  ) schema.schemas;
  structureInfoJson = builtins.toJSON structureInfoMap;
  
  # Build expected config files per version
  expectedConfigFilesMap = lib.mapAttrs (version: schema:
    schema.expectedConfigFiles or []
  ) schema.schemas;
  expectedConfigFilesJson = builtins.toJSON expectedConfigFilesMap;
  
  # Validation script that validates system-config.nix structure
  validateSystemConfig = pkgs.writeShellScriptBin "ncc-validate-config" ''
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
    CONFIGS_DIR="/etc/nixos/configs"
    
    ERRORS=0
    WARNINGS=0
    
    # Check if system-config.nix exists
    if [ ! -f "$SYSTEM_CONFIG" ]; then
      ${formatter.messages.error "system-config.nix not found at $SYSTEM_CONFIG"}
      exit 1
    fi
    
    if [ "$VERBOSE" = "true" ]; then
      ${formatter.messages.info "Validating system-config.nix..."}
    fi
    
    # Validate Nix syntax
    if ! ${pkgs.nix}/bin/nix-instantiate --parse "$SYSTEM_CONFIG" >/dev/null 2>&1; then
      ${formatter.messages.error "system-config.nix has invalid Nix syntax"}
      ERRORS=$((ERRORS + 1))
    else
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.messages.success "Nix syntax is valid"}
      fi
    fi
    
    # MODERN VERSION DETECTION: Use detectionPatterns from schemas via detection module
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
    
    # Check if version is supported
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
    
    # Check if migration is needed (version mismatch)
    if [ "$CONFIG_VERSION" != "$CURRENT_VERSION" ]; then
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.messages.warning "Config version $CONFIG_VERSION does not match current version $CURRENT_VERSION"}
        ${formatter.messages.info "Migration needed - this will be handled automatically"}
      fi
      # Count as error to trigger migration in config-check
      ERRORS=$((ERRORS + 1))
    fi
    
    # Get required fields for this version from schema
    REQUIRED_FIELDS=$(echo "$REQUIRED_FIELDS_MAP" | ${pkgs.jq}/bin/jq -r ".\"$CONFIG_VERSION\" // [] | .[]")
    
    # Check for required fields
    for field in $REQUIRED_FIELDS; do
      if ! ${pkgs.nix}/bin/nix-instantiate --eval --strict -E \
        "(import $SYSTEM_CONFIG).$field or null" >/dev/null 2>&1; then
        if [ "$VERBOSE" = "true" ]; then
          ${formatter.messages.warning "Required field '$field' not found in system-config.nix (v$CONFIG_VERSION)"}
        fi
        WARNINGS=$((WARNINGS + 1))
      else
        if [ "$VERBOSE" = "true" ]; then
          ${formatter.messages.success "$field found"}
        fi
      fi
    done
    
    # Get structure info for this version
    STRUCTURE_INFO=$(echo "$STRUCTURE_INFO_MAP" | ${pkgs.jq}/bin/jq -r ".\"$CONFIG_VERSION\" // {}")
    MAX_LINES=$(echo "$STRUCTURE_INFO" | ${pkgs.jq}/bin/jq -r '.maxSystemConfigLines // 9999')
    FORBIDDEN_FIELDS=$(echo "$STRUCTURE_INFO" | ${pkgs.jq}/bin/jq -r '.forbiddenInSystemConfig // [] | .[]')
    
    # Check if structure is minimal (for modular versions)
    if [ "$MAX_LINES" -lt 9999 ]; then
      LINE_COUNT=$(wc -l < "$SYSTEM_CONFIG" 2>/dev/null || echo "0")
      if [ "$LINE_COUNT" -gt "$MAX_LINES" ]; then
        if [ "$VERBOSE" = "true" ]; then
          ${formatter.messages.warning "system-config.nix has more than $MAX_LINES lines (should be minimal for v$CONFIG_VERSION)"}
          ${formatter.messages.info "Consider running 'ncc-migrate-config' to migrate to modular structure"}
        fi
        WARNINGS=$((WARNINGS + 1))
      fi
    fi
    
    # Check for forbidden fields in system-config.nix
    for field in $FORBIDDEN_FIELDS; do
      if grep -q "$field = {" "$SYSTEM_CONFIG" 2>/dev/null || \
         grep -q "$field = " "$SYSTEM_CONFIG" 2>/dev/null; then
        if [ "$VERBOSE" = "true" ]; then
          ${formatter.messages.warning "Non-critical field '$field' found in system-config.nix (v$CONFIG_VERSION)"}
          ${formatter.messages.info "This should be in separate configs/ files"}
          ${formatter.messages.info "Consider running 'ncc-migrate-config' to migrate to modular structure"}
        fi
        WARNINGS=$((WARNINGS + 1))
      fi
    done
    
    # Check if configs directory exists (for modular versions)
    # Note: hasConfigsDir is not in JSON, we check directory directly
    if [ "$CONFIG_VERSION" != "1.0" ]; then
      # v1.0+ expects configs dir
      if [ ! -d "$CONFIGS_DIR" ]; then
        if [ "$VERBOSE" = "true" ]; then
          ${formatter.messages.info "configs/ directory does not exist (recommended for modular config v$CONFIG_VERSION)"}
        fi
      else
        if [ "$VERBOSE" = "true" ]; then
          ${formatter.messages.success "configs/ directory exists"}
        fi
        
        # Get expected config files for this version
        EXPECTED_FILES=$(echo "$EXPECTED_CONFIG_FILES_MAP" | ${pkgs.jq}/bin/jq -r ".\"$CONFIG_VERSION\" // [] | .[]")
        
        # Validate each config file
        for config_file in "$CONFIGS_DIR"/*.nix; do
          if [ -f "$config_file" ]; then
            CONFIG_BASENAME=$(basename "$config_file")
            if ${pkgs.nix}/bin/nix-instantiate --parse "$config_file" >/dev/null 2>&1; then
              if [ "$VERBOSE" = "true" ]; then
                ${formatter.messages.success "  $CONFIG_BASENAME syntax is valid"}
              fi
            else
              ${formatter.messages.error "  $CONFIG_BASENAME has invalid Nix syntax"}
              ERRORS=$((ERRORS + 1))
            fi
          fi
        done
      fi
    fi
    
    # If v0, suggest migration
    if [ "$CONFIG_VERSION" = "1.0" ] && [ "$CONFIG_VERSION" != "$CURRENT_VERSION" ]; then
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.messages.info "v0 structure detected (monolithic)"}
        ${formatter.messages.info "Consider running 'ncc-migrate-config' to migrate to v$CURRENT_VERSION (modular structure)"}
      fi
    fi
    
    # Summary
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

