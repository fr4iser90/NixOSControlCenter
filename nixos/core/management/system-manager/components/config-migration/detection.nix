{ pkgs, lib, ... }:

let
  schema = import ./schema.nix { inherit lib; };
  
  # Extract detectionPatterns from all schemas
  detectionPatternsMap = lib.mapAttrs (version: schemaAttrs:
    schemaAttrs.detectionPatterns or []
  ) schema.schemas;
  
  # Convert to JSON for bash script
  detectionPatternsJson = builtins.toJSON detectionPatternsMap;
  
  currentVersion = schema.currentVersion;
  minSupportedVersion = schema.minSupportedVersion;
  supportedVersions = lib.attrNames schema.schemas;
in

{
  # Version detection script using detectionPatterns from schemas
  detectConfigVersion = pkgs.writeScriptBin "ncc-detect-version" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # Generic config directory - can be overridden via environment variable
    NIXOS_CONFIG_DIR="''${NIXOS_CONFIG_DIR:-/etc/nixos}"
    SYSTEM_CONFIG="$NIXOS_CONFIG_DIR/system-config.nix"
    CONFIGS_DIR="$NIXOS_CONFIG_DIR/configs"
    
    # Set jq path
    JQ_BIN="${pkgs.jq}/bin/jq"
    
    # Check if system-config.nix exists
    if [ ! -f "$SYSTEM_CONFIG" ]; then
      echo "ERROR: system-config.nix not found at $SYSTEM_CONFIG" >&2
      exit 1
    fi
    
    # Try to load config as JSON first (to check for explicit configVersion)
    CONFIG_JSON=''$(${pkgs.nix}/bin/nix-instantiate --eval --strict --json -E "import $SYSTEM_CONFIG" 2>/dev/null || echo "{}")
    
    # Check if we got valid JSON
    if echo "$CONFIG_JSON" | "$JQ_BIN" . >/dev/null 2>&1; then
      # Check if configVersion exists in JSON
      HAS_CONFIG_VERSION=''$("$JQ_BIN" -r 'has("configVersion")' <<< "$CONFIG_JSON")
      
      if [ "$HAS_CONFIG_VERSION" = "true" ]; then
        # Use explicit configVersion from config
        DETECTED_VERSION=''$("$JQ_BIN" -r '.configVersion' <<< "$CONFIG_JSON")
        echo "$DETECTED_VERSION"
        exit 0
      fi
    fi
    
    # Pattern-based detection: Read config file as text and check patterns
    CONFIG_TEXT=$(cat "$SYSTEM_CONFIG" 2>/dev/null || echo "")
    
    if [ -z "$CONFIG_TEXT" ]; then
      echo "ERROR: Could not read system-config.nix" >&2
      exit 1
    fi
    
    # Get detection patterns from schemas (embedded at build time)
    DETECTION_PATTERNS='${detectionPatternsJson}'
    SUPPORTED_VERSIONS="${toString supportedVersions}"
    MIN_SUPPORTED="${minSupportedVersion}"
    
    DETECTED_VERSION=""
    HIGHEST_MATCH_COUNT=0
    
    # Check each version's patterns
    for version in $SUPPORTED_VERSIONS; do
      PATTERNS=''$(echo "$DETECTION_PATTERNS" | "$JQ_BIN" -r ".\"$version\" // [] | .[]")
      
      if [ -z "$PATTERNS" ]; then
        continue
      fi
      
      MATCH_COUNT=0
      for pattern in $PATTERNS; do
        # Check if pattern exists in config text (case-insensitive, as substring)
        if echo "$CONFIG_TEXT" | grep -qiF "$pattern"; then
          MATCH_COUNT=$((MATCH_COUNT + 1))
        fi
      done
      
      # If this version has more matches, it's more likely
      if [ "$MATCH_COUNT" -gt "$HIGHEST_MATCH_COUNT" ]; then
        HIGHEST_MATCH_COUNT=$MATCH_COUNT
        DETECTED_VERSION="$version"
      fi
    done
    
    # If we found a version with matching patterns, use it
    if [ -n "$DETECTED_VERSION" ] && [ "$HIGHEST_MATCH_COUNT" -gt 0 ]; then
      echo "$DETECTED_VERSION"
      exit 0
    fi
    
    # Fallback: Check if configs/ directory exists (indicates v1.0+)
    if [ -d "$CONFIGS_DIR" ]; then
      echo "1.0"
      exit 0
    fi
    
    # Final fallback: Use minSupportedVersion
    echo "$MIN_SUPPORTED"
    exit 0
  '';
}
