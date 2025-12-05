{ pkgs, lib, ... }:

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
    
    SYSTEM_CONFIG="/etc/nixos/system-config.nix"
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
    
    # MODERN VERSION DETECTION: Use detectionPatterns from schemas via detection module
    CONFIG_VERSION=''$(${detection.detectConfigVersion}/bin/ncc-detect-version)
    CURRENT_VERSION="${currentVersion}"
    SUPPORTED_VERSIONS="${toString supportedVersions}"
    REQUIRED_FIELDS_MAP='${requiredFieldsJson}'
    STRUCTURE_INFO_MAP='${structureInfoJson}'
    EXPECTED_CONFIG_FILES_MAP='${expectedConfigFilesJson}'
    
    echo "✓ Detected config version: $CONFIG_VERSION"
    echo "✓ Current supported version: $CURRENT_VERSION"
    echo "✓ Supported versions: $SUPPORTED_VERSIONS"
    
    # Check if version is supported
    VERSION_SUPPORTED=false
    for v in $SUPPORTED_VERSIONS; do
      if [ "$v" = "$CONFIG_VERSION" ]; then
        VERSION_SUPPORTED=true
        break
      fi
    done
    
    if [ "$VERSION_SUPPORTED" = "false" ]; then
      echo "WARNING: Config version $CONFIG_VERSION not recognized (assuming v1.0)"
      CONFIG_VERSION="1.0"
    fi
    
    # Check if migration is needed (version mismatch)
    if [ "$CONFIG_VERSION" != "$CURRENT_VERSION" ]; then
      echo "ERROR: Config version $CONFIG_VERSION does not match current version $CURRENT_VERSION"
      echo "       Migration needed - this will be handled automatically"
      # Count as error to trigger migration in config-check
      ERRORS=$((ERRORS + 1))
    fi
    
    # Get required fields for this version from schema
    REQUIRED_FIELDS=$(echo "$REQUIRED_FIELDS_MAP" | ${pkgs.jq}/bin/jq -r ".\"$CONFIG_VERSION\" // [] | .[]")
    
    # Check for required fields
    for field in $REQUIRED_FIELDS; do
      if ! ${pkgs.nix}/bin/nix-instantiate --eval --strict -E \
        "(import $SYSTEM_CONFIG).$field or null" >/dev/null 2>&1; then
        echo "WARNING: Required field '$field' not found in system-config.nix (v$CONFIG_VERSION)"
        WARNINGS=$((WARNINGS + 1))
      else
        echo "✓ $field found"
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
        echo "WARNING: system-config.nix has more than $MAX_LINES lines (should be minimal for v$CONFIG_VERSION)"
        echo "         Consider running 'ncc-migrate-config' to migrate to modular structure"
        WARNINGS=$((WARNINGS + 1))
      fi
    fi
    
    # Check for forbidden fields in system-config.nix
    for field in $FORBIDDEN_FIELDS; do
      if grep -q "$field = {" "$SYSTEM_CONFIG" 2>/dev/null || \
         grep -q "$field = " "$SYSTEM_CONFIG" 2>/dev/null; then
        echo "WARNING: Non-critical field '$field' found in system-config.nix (v$CONFIG_VERSION)"
        echo "         This should be in separate configs/ files"
        echo "         Consider running 'ncc-migrate-config' to migrate to modular structure"
        WARNINGS=$((WARNINGS + 1))
      fi
    done
    
    # Check if configs directory exists (for modular versions)
    # Note: hasConfigsDir is not in JSON, we check directory directly
    if [ "$CONFIG_VERSION" != "1.0" ]; then
      # v2.0+ expects configs dir
      if [ ! -d "$CONFIGS_DIR" ]; then
        echo "INFO: configs/ directory does not exist (recommended for modular config v$CONFIG_VERSION)"
      else
        echo "✓ configs/ directory exists"
        
        # Get expected config files for this version
        EXPECTED_FILES=$(echo "$EXPECTED_CONFIG_FILES_MAP" | ${pkgs.jq}/bin/jq -r ".\"$CONFIG_VERSION\" // [] | .[]")
        
        # Validate each config file
        for config_file in "$CONFIGS_DIR"/*.nix; do
          if [ -f "$config_file" ]; then
            if ${pkgs.nix}/bin/nix-instantiate --parse "$config_file" >/dev/null 2>&1; then
              echo "  ✓ $(basename "$config_file") syntax is valid"
            else
              echo "  ERROR: $(basename "$config_file") has invalid Nix syntax"
              ERRORS=$((ERRORS + 1))
            fi
          fi
        done
      fi
    fi
    
    # If v1.0, suggest migration
    if [ "$CONFIG_VERSION" = "1.0" ] && [ "$CONFIG_VERSION" != "$CURRENT_VERSION" ]; then
      echo "INFO: v1.0 structure detected (monolithic)"
      echo "      Consider running 'ncc-migrate-config' to migrate to v$CURRENT_VERSION (modular structure)"
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

