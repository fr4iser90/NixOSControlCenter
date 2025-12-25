{ pkgs, cfg, scanners }:

pkgs.writeShellScriptBin "generate-snapshot" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail
  
  OUTPUT_FILE=""
  SCAN_DESKTOP=false
  SCAN_STEAM=false
  SCAN_CREDENTIALS=false
  SCAN_PACKAGES=false
  SCAN_BROWSER=false
  SCAN_IDE=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --output)
        OUTPUT_FILE="$2"
        shift 2
        ;;
      --desktop)
        SCAN_DESKTOP=true
        shift
        ;;
      --steam)
        SCAN_STEAM=true
        shift
        ;;
      --credentials)
        SCAN_CREDENTIALS=true
        shift
        ;;
      --packages)
        SCAN_PACKAGES=true
        shift
        ;;
      --browser)
        SCAN_BROWSER=true
        shift
        ;;
      --ide)
        SCAN_IDE=true
        shift
        ;;
      *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
  done
  
  if [ -z "$OUTPUT_FILE" ]; then
    echo "Error: --output is required"
    exit 1
  fi
  
  # Create temp directory for scanner outputs
  TEMP_DIR=$(mktemp -d)
  trap "rm -rf $TEMP_DIR" EXIT
  
  # Initialize base snapshot
  SNAPSHOT=$(${pkgs.jq}/bin/jq -n \
    --arg hostname "$(hostname)" \
    --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg nixosVersion "$(nixos-version 2>/dev/null || echo "unknown")" \
    '{
      metadata: {
        hostname: $hostname,
        timestamp: $timestamp,
        nixosVersion: $nixosVersion,
        scannerVersion: "1.0"
      }
    }')
  
  # Run enabled scanners
  if [ "$SCAN_DESKTOP" = "true" ]; then
    DESKTOP_OUTPUT="$TEMP_DIR/desktop.json"
    ${scanners.desktop}/bin/scan-desktop "$DESKTOP_OUTPUT"
    if [ -f "$DESKTOP_OUTPUT" ]; then
      DESKTOP_DATA=$(cat "$DESKTOP_OUTPUT")
      SNAPSHOT=$(echo "$SNAPSHOT" | ${pkgs.jq}/bin/jq --argjson desktop "$DESKTOP_DATA" '. + $desktop')
    fi
  fi
  
  if [ "$SCAN_STEAM" = "true" ]; then
    STEAM_OUTPUT="$TEMP_DIR/steam.json"
    ${scanners.steam}/bin/scan-steam "$STEAM_OUTPUT"
    if [ -f "$STEAM_OUTPUT" ]; then
      STEAM_DATA=$(cat "$STEAM_OUTPUT")
      SNAPSHOT=$(echo "$SNAPSHOT" | ${pkgs.jq}/bin/jq --argjson steam "$STEAM_DATA" '. + $steam')
    fi
  fi
  
  if [ "$SCAN_CREDENTIALS" = "true" ]; then
    CREDENTIALS_OUTPUT="$TEMP_DIR/credentials.json"
    ${scanners.credentials}/bin/scan-credentials "$CREDENTIALS_OUTPUT"
    if [ -f "$CREDENTIALS_OUTPUT" ]; then
      CREDENTIALS_DATA=$(cat "$CREDENTIALS_OUTPUT")
      SNAPSHOT=$(echo "$SNAPSHOT" | ${pkgs.jq}/bin/jq --argjson credentials "$CREDENTIALS_DATA" '. + $credentials')
    fi
  fi
  
  if [ "$SCAN_PACKAGES" = "true" ]; then
    PACKAGES_OUTPUT="$TEMP_DIR/packages.json"
    ${scanners.packages}/bin/scan-packages "$PACKAGES_OUTPUT"
    if [ -f "$PACKAGES_OUTPUT" ]; then
      PACKAGES_DATA=$(cat "$PACKAGES_OUTPUT")
      SNAPSHOT=$(echo "$SNAPSHOT" | ${pkgs.jq}/bin/jq --argjson packages "$PACKAGES_DATA" '. + $packages')
    fi
  fi
  
  if [ "$SCAN_BROWSER" = "true" ]; then
    BROWSER_OUTPUT="$TEMP_DIR/browser.json"
    ${scanners.browser}/bin/scan-browser "$BROWSER_OUTPUT"
    if [ -f "$BROWSER_OUTPUT" ]; then
      BROWSER_DATA=$(cat "$BROWSER_OUTPUT")
      SNAPSHOT=$(echo "$SNAPSHOT" | ${pkgs.jq}/bin/jq --argjson browser "$BROWSER_DATA" '. + $browser')
    fi
  fi
  
  if [ "$SCAN_IDE" = "true" ]; then
    IDE_OUTPUT="$TEMP_DIR/ide.json"
    ${scanners.ide}/bin/scan-ide "$IDE_OUTPUT"
    if [ -f "$IDE_OUTPUT" ]; then
      IDE_DATA=$(cat "$IDE_OUTPUT")
      SNAPSHOT=$(echo "$SNAPSHOT" | ${pkgs.jq}/bin/jq --argjson ide "$IDE_DATA" '. + $ide')
    fi
  fi
  
  # Write final snapshot
  echo "$SNAPSHOT" | ${pkgs.jq}/bin/jq '.' > "$OUTPUT_FILE"
  
  echo "✅ Snapshot generated: $OUTPUT_FILE"
''

