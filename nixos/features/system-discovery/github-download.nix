{ pkgs, lib, cfg }:

with lib;

pkgs.writeShellScriptBin "download-from-github" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail
  
  REPOSITORY=""
  BRANCH="main"
  TOKEN_FILE=""
  SNAPSHOT_NAME=""
  OUTPUT_DIR=""
  LIST_ONLY=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --repository)
        REPOSITORY="$2"
        shift 2
        ;;
      --branch)
        BRANCH="$2"
        shift 2
        ;;
      --token-file)
        TOKEN_FILE="$2"
        shift 2
        ;;
      --snapshot)
        SNAPSHOT_NAME="$2"
        shift 2
        ;;
      --output)
        OUTPUT_DIR="$2"
        shift 2
        ;;
      --list)
        LIST_ONLY=true
        shift
        ;;
      *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
  done
  
  if [ -z "$REPOSITORY" ]; then
    REPOSITORY="${cfg.github.repository}"
  fi
  
  if [ -z "$REPOSITORY" ]; then
    echo "Error: --repository is required (format: owner/repo)"
    exit 1
  fi
  
  # Extract owner and repo
  OWNER=$(echo "$REPOSITORY" | cut -d'/' -f1)
  REPO=$(echo "$REPOSITORY" | cut -d'/' -f2)
  
  if [ -z "$OWNER" ] || [ -z "$REPO" ]; then
    echo "Error: Invalid repository format. Use 'owner/repo'"
    exit 1
  fi
  
  # Get GitHub token
  GITHUB_TOKEN=""
  if [ -n "$TOKEN_FILE" ] && [ -f "$TOKEN_FILE" ]; then
    if command -v sops >/dev/null 2>&1 && sops -d "$TOKEN_FILE" >/dev/null 2>&1; then
      GITHUB_TOKEN=$(sops -d "$TOKEN_FILE" | tr -d '\n' || cat "$TOKEN_FILE" | tr -d '\n')
    else
      GITHUB_TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n')
    fi
  elif [ -n "${cfg.github.tokenFile}" ] && [ -f "${cfg.github.tokenFile}" ]; then
    if command -v sops >/dev/null 2>&1 && sops -d "${cfg.github.tokenFile}" >/dev/null 2>&1; then
      GITHUB_TOKEN=$(sops -d "${cfg.github.tokenFile}" | tr -d '\n' || cat "${cfg.github.tokenFile}" | tr -d '\n')
    else
      GITHUB_TOKEN=$(cat "${cfg.github.tokenFile}" | tr -d '\n')
    fi
  elif [ -n "$GITHUB_TOKEN" ]; then
    GITHUB_TOKEN="$GITHUB_TOKEN"
  else
    echo "Error: GitHub token required. Set --token-file or GITHUB_TOKEN environment variable"
    exit 1
  fi
  
  # Set output directory
  if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="${cfg.snapshotDir}"
  fi
  
  mkdir -p "$OUTPUT_DIR"
  
  # List snapshots
  echo "📥 Fetching snapshots from GitHub..."
  
  # Use GitHub API to list files in snapshots directory
  API_URL="https://api.github.com/repos/$REPOSITORY/contents/snapshots?ref=$BRANCH"
  
  SNAPSHOTS_JSON=$(${pkgs.curl}/bin/curl -s -H "Authorization: token $GITHUB_TOKEN" "$API_URL" || echo "[]")
  
  if [ "$SNAPSHOTS_JSON" = "[]" ] || echo "$SNAPSHOTS_JSON" | ${pkgs.jq}/bin/jq -e '.message' >/dev/null 2>&1; then
    echo "⚠️  Could not fetch snapshots. Check repository, branch, and token permissions."
    exit 1
  fi
  
  # Filter snapshot files
  SNAPSHOT_FILES=$(${pkgs.jq}/bin/jq -r '.[] | select(.name | endswith(".json") or endswith(".encrypted")) | .name' <<< "$SNAPSHOTS_JSON")
  
  if [ -z "$SNAPSHOT_FILES" ]; then
    echo "⚠️  No snapshots found in repository"
    exit 0
  fi
  
  # List snapshots
  echo ""
  echo "Available snapshots:"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  SNAPSHOT_LIST=()
  while IFS= read -r filename; do
    if [ -n "$filename" ]; then
      # Get file info from API
      FILE_INFO=$(echo "$SNAPSHOTS_JSON" | ${pkgs.jq}/bin/jq -r ".[] | select(.name == \"$filename\")")
      SIZE=$(echo "$FILE_INFO" | ${pkgs.jq}/bin/jq -r '.size // 0')
      DATE=$(echo "$FILE_INFO" | ${pkgs.jq}/bin/jq -r '.updated_at // .created_at // "unknown"')
      
      # Calculate size in MB (without bc dependency)
      if [ "$SIZE" -gt 0 ] 2>/dev/null; then
        SIZE_MB=$(awk "BEGIN {printf \"%.2f\", $SIZE / 1024 / 1024}")
      else
        SIZE_MB="?"
      fi
      
      echo "  📦 $filename"
      echo "     Size: $SIZE_MB MB | Updated: $DATE"
      echo ""
      
      SNAPSHOT_LIST+=("$filename")
    fi
  done <<< "$SNAPSHOT_FILES"
  
  if [ "$LIST_ONLY" = "true" ]; then
    exit 0
  fi
  
  # Download specific snapshot or latest
  if [ -z "$SNAPSHOT_NAME" ]; then
    # Get latest snapshot (by name/timestamp)
    LATEST_SNAPSHOT=$(printf '%s\n' "''${SNAPSHOT_LIST[@]}" | sort -r | head -1)
    SNAPSHOT_NAME="$LATEST_SNAPSHOT"
    echo "📥 Downloading latest snapshot: $SNAPSHOT_NAME"
  else
    # Check if snapshot exists
    if ! printf '%s\n' "''${SNAPSHOT_LIST[@]}" | grep -q "^$SNAPSHOT_NAME$"; then
      echo "❌ Snapshot '$SNAPSHOT_NAME' not found"
      echo "Available snapshots:"
      printf '  - %s\n' "''${SNAPSHOT_LIST[@]}"
      exit 1
    fi
    echo "📥 Downloading snapshot: $SNAPSHOT_NAME"
  fi
  
  # Get download URL
  DOWNLOAD_URL=$(echo "$SNAPSHOTS_JSON" | ${pkgs.jq}/bin/jq -r ".[] | select(.name == \"$SNAPSHOT_NAME\") | .download_url")
  
  if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
    echo "❌ Could not get download URL for snapshot"
    exit 1
  fi
  
  # Download file
  OUTPUT_FILE="$OUTPUT_DIR/$SNAPSHOT_NAME"
  
  if ${pkgs.curl}/bin/curl -s -H "Authorization: token $GITHUB_TOKEN" -L "$DOWNLOAD_URL" -o "$OUTPUT_FILE"; then
    echo "✅ Downloaded: $OUTPUT_FILE"
    echo ""
    echo "To restore, run:"
    echo "  ncc-restore --snapshot $OUTPUT_FILE --all"
  else
    echo "❌ Failed to download snapshot"
    exit 1
  fi
''

