{ lib, pkgs, cfg }:

# Dropbox Upload via API
# Uses Dropbox API v2

pkgs.writeShellScriptBin "chronicle-dropbox" ''
  #!/usr/bin/env bash
  set -euo pipefail

  # Configuration
  DROPBOX_TOKEN="''${DROPBOX_TOKEN:-}"
  DROPBOX_PATH="''${DROPBOX_PATH:-/chronicle}"
  
  usage() {
    cat << EOF
  Dropbox Upload for Step Recorder
  
  Usage: chronicle-dropbox <command> [options]
  
  Commands:
    upload <session_id>           - Upload session to Dropbox
    upload-auto                   - Upload latest session
    list                          - List uploaded sessions
    download <session_id>         - Download session from Dropbox
    delete <session_id>           - Delete session from Dropbox
    share <session_id>            - Create share link
    test                          - Test Dropbox connection
    
  Options:
    --format zip                 - Upload format (zip/html/pdf/all)
    --share                      - Create public share link
    
  Environment Variables:
    DROPBOX_TOKEN                - Dropbox Access Token
    DROPBOX_PATH                 - Upload path (default: /chronicle)
    
  Getting a Dropbox Access Token:
    1. Go to https://www.dropbox.com/developers/apps
    2. Create a new app
    3. Select "Scoped access" and "Full Dropbox"
    4. Generate an access token
    
  Example:
    export DROPBOX_TOKEN="sl.xxxxxxxxxxxxxxxxxxxxxxxxx"
    chronicle-dropbox upload-auto --format zip --share
  EOF
  }
  
  # Colors
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
  
  log() { echo -e "''${BLUE}[INFO]''${NC} $*"; }
  success() { echo -e "''${GREEN}[SUCCESS]''${NC} $*"; }
  warn() { echo -e "''${YELLOW}[WARN]''${NC} $*"; }
  error() { echo -e "''${RED}[ERROR]''${NC} $*"; }
  
  check_requirements() {
    [ -z "$DROPBOX_TOKEN" ] && { error "DROPBOX_TOKEN not set"; exit 1; }
  }
  
  test_connection() {
    log "Testing Dropbox connection..."
    
    response=$(${pkgs.curl}/bin/curl -s -w "\n%{http_code}" \
      -H "Authorization: Bearer $DROPBOX_TOKEN" \
      https://api.dropboxapi.com/2/users/get_current_account \
      -d null)
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
      display_name=$(echo "$body" | ${pkgs.jq}/bin/jq -r '.name.display_name')
      email=$(echo "$body" | ${pkgs.jq}/bin/jq -r '.email')
      success "Connected to Dropbox"
      log "User: $display_name ($email)"
      return 0
    else
      error "Failed to connect (HTTP $http_code)"
      echo "$body" | ${pkgs.jq}/bin/jq -r '.error_summary // "Unknown error"'
      exit 1
    fi
  }
  
  get_latest_session() {
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    latest=$(ls -td "$output_dir"/session_* 2>/dev/null | head -n1)
    [ -z "$latest" ] && { error "No sessions found"; exit 1; }
    basename "$latest"
  }
  
  upload_file() {
    local local_path="$1"
    local dropbox_path="$2"
    
    ${pkgs.curl}/bin/curl -s -X POST https://content.dropboxapi.com/2/files/upload \
      --header "Authorization: Bearer $DROPBOX_TOKEN" \
      --header "Dropbox-API-Arg: {\"path\": \"$dropbox_path\",\"mode\": \"overwrite\",\"autorename\": false,\"mute\": false}" \
      --header "Content-Type: application/octet-stream" \
      --data-binary @"$local_path"
  }
  
  upload_session() {
    local session_id="$1"
    local format="''${2:-zip}"
    local create_share="''${3:-false}"
    
    log "Uploading session: $session_id (format: $format)"
    
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    local session_dir="$output_dir/$session_id"
    
    [ ! -d "$session_dir" ] && { error "Session not found: $session_id"; exit 1; }
    
    if [ "$format" = "zip" ] || [ "$format" = "all" ]; then
      log "Creating ZIP archive..."
      local zip_file="$session_dir/$session_id.zip"
      
      if [ ! -f "$zip_file" ]; then
        cd "$session_dir"
        ${pkgs.zip}/bin/zip -r "$zip_file" . -x "*.zip" >/dev/null
        cd - >/dev/null
      fi
      
      log "Uploading ZIP to Dropbox..."
      upload_file "$zip_file" "$DROPBOX_PATH/$session_id/$session_id.zip"
      success "ZIP uploaded"
    fi
    
    if [ "$format" = "html" ] || [ "$format" = "all" ]; then
      local html_file="$session_dir/$session_id.html"
      if [ -f "$html_file" ]; then
        log "Uploading HTML..."
        upload_file "$html_file" "$DROPBOX_PATH/$session_id/$session_id.html"
        success "HTML uploaded"
      fi
    fi
    
    if [ "$format" = "all" ]; then
      log "Uploading all session files..."
      for file in "$session_dir"/*; do
        [ -f "$file" ] || continue
        [ "$(basename "$file")" = "$session_id.zip" ] && continue
        filename=$(basename "$file")
        upload_file "$file" "$DROPBOX_PATH/$session_id/$filename"
      done
      success "All files uploaded"
    fi
    
    # Create share link if requested
    if [ "$create_share" = "true" ]; then
      log "Creating share link..."
      create_share_link "$session_id"
    fi
    
    success "Upload complete!"
    log "Path: $DROPBOX_PATH/$session_id"
    
    ${pkgs.libnotify}/bin/notify-send "Dropbox Upload Complete" \
      "Session $session_id uploaded" \
      --icon=dialog-information 2>/dev/null || true
  }
  
  create_share_link() {
    local session_id="$1"
    
    response=$(${pkgs.curl}/bin/curl -s -X POST \
      https://api.dropboxapi.com/2/sharing/create_shared_link_with_settings \
      -H "Authorization: Bearer $DROPBOX_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"path\": \"$DROPBOX_PATH/$session_id/$session_id.zip\",\"settings\": {\"requested_visibility\": \"public\"}}")
    
    share_url=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.url // empty')
    
    if [ -n "$share_url" ]; then
      # Convert to direct download link
      share_url=$(echo "$share_url" | sed 's/www\.dropbox\.com/dl.dropboxusercontent.com/g' | sed 's/?dl=0/?dl=1/g')
      success "Share link created:"
      echo "$share_url"
    else
      # Try to get existing link
      response=$(${pkgs.curl}/bin/curl -s -X POST \
        https://api.dropboxapi.com/2/sharing/list_shared_links \
        -H "Authorization: Bearer $DROPBOX_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"path\": \"$DROPBOX_PATH/$session_id/$session_id.zip\"}")
      
      share_url=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.links[0].url // empty')
      if [ -n "$share_url" ]; then
        share_url=$(echo "$share_url" | sed 's/www\.dropbox\.com/dl.dropboxusercontent.com/g' | sed 's/?dl=0/?dl=1/g')
        success "Share link (existing):"
        echo "$share_url"
      else
        warn "Could not create share link"
      fi
    fi
  }
  
  list_sessions() {
    log "Listing sessions in Dropbox..."
    
    response=$(${pkgs.curl}/bin/curl -s -X POST \
      https://api.dropboxapi.com/2/files/list_folder \
      -H "Authorization: Bearer $DROPBOX_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"path\": \"$DROPBOX_PATH\"}")
    
    echo "$response" | ${pkgs.jq}/bin/jq -r '.entries[] | select(.".tag" == "folder") | .name'
  }
  
  download_session() {
    local session_id="$1"
    log "Downloading session: $session_id"
    
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    local download_dir="$output_dir/$session_id"
    
    mkdir -p "$download_dir"
    
    ${pkgs.curl}/bin/curl -X POST https://content.dropboxapi.com/2/files/download \
      --header "Authorization: Bearer $DROPBOX_TOKEN" \
      --header "Dropbox-API-Arg: {\"path\": \"$DROPBOX_PATH/$session_id/$session_id.zip\"}" \
      -o "$download_dir/$session_id.zip"
    
    cd "$download_dir"
    ${pkgs.unzip}/bin/unzip -q "$session_id.zip"
    rm "$session_id.zip"
    cd - >/dev/null
    
    success "Downloaded to: $download_dir"
  }
  
  delete_session() {
    local session_id="$1"
    log "Deleting session from Dropbox: $session_id"
    
    read -p "Are you sure? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log "Cancelled"
      exit 0
    fi
    
    ${pkgs.curl}/bin/curl -s -X POST \
      https://api.dropboxapi.com/2/files/delete_v2 \
      -H "Authorization: Bearer $DROPBOX_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"path\": \"$DROPBOX_PATH/$session_id\"}"
    
    success "Session deleted from Dropbox"
  }
  
  case "''${1:-help}" in
    upload)
      [ -z "''${2:-}" ] && { error "Session ID required"; exit 1; }
      check_requirements
      upload_session "$2" "''${3:-zip}" "''${4:-false}"
      ;;
    upload-auto)
      check_requirements
      session_id=$(get_latest_session)
      log "Using latest session: $session_id"
      upload_session "$session_id" "''${2:-zip}" "''${3:-false}"
      ;;
    list)
      check_requirements
      list_sessions
      ;;
    download)
      [ -z "''${2:-}" ] && { error "Session ID required"; exit 1; }
      check_requirements
      download_session "$2"
      ;;
    delete)
      [ -z "''${2:-}" ] && { error "Session ID required"; exit 1; }
      check_requirements
      delete_session "$2"
      ;;
    share)
      [ -z "''${2:-}" ] && { error "Session ID required"; exit 1; }
      check_requirements
      create_share_link "$2"
      ;;
    test)
      check_requirements
      test_connection
      ;;
    help|*)
      usage
      ;;
  esac
''
