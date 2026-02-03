{ lib, pkgs, cfg }:

# Nextcloud WebDAV Upload
# Also works with other WebDAV services (ownCloud, generic WebDAV)

pkgs.writeShellScriptBin "chronicle-nextcloud" ''
  #!/usr/bin/env bash
  set -euo pipefail

  # Configuration
  NEXTCLOUD_URL="''${NEXTCLOUD_URL:-}"
  NEXTCLOUD_USER="''${NEXTCLOUD_USER:-}"
  NEXTCLOUD_PASSWORD="''${NEXTCLOUD_PASSWORD:-}"
  NEXTCLOUD_PATH="''${NEXTCLOUD_PATH:-/chronicle}"
  
  usage() {
    cat << EOF
  Nextcloud/WebDAV Upload for Step Recorder
  
  Usage: chronicle-nextcloud <command> [options]
  
  Commands:
    upload <session_id>           - Upload session to Nextcloud
    upload-auto                   - Upload latest session
    list                          - List uploaded sessions
    download <session_id>         - Download session from Nextcloud
    delete <session_id>           - Delete session from Nextcloud
    share <session_id>            - Create share link
    test                          - Test Nextcloud connection
    
  Options:
    --format zip                 - Upload format (zip/html/pdf/all)
    --share                      - Create public share link
    
  Environment Variables:
    NEXTCLOUD_URL                - Nextcloud base URL (e.g., https://cloud.example.com)
    NEXTCLOUD_USER               - Username
    NEXTCLOUD_PASSWORD           - Password or app password
    NEXTCLOUD_PATH               - Upload path (default: /chronicle)
    
  Examples:
    export NEXTCLOUD_URL="https://cloud.example.com"
    export NEXTCLOUD_USER="myuser"
    export NEXTCLOUD_PASSWORD="app-password-here"
    
    chronicle-nextcloud upload-auto --format zip --share
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
    [ -z "$NEXTCLOUD_URL" ] && { error "NEXTCLOUD_URL not set"; exit 1; }
    [ -z "$NEXTCLOUD_USER" ] && { error "NEXTCLOUD_USER not set"; exit 1; }
    [ -z "$NEXTCLOUD_PASSWORD" ] && { error "NEXTCLOUD_PASSWORD not set"; exit 1; }
  }
  
  # WebDAV endpoint
  webdav_url() {
    echo "$NEXTCLOUD_URL/remote.php/dav/files/$NEXTCLOUD_USER"
  }
  
  test_connection() {
    log "Testing Nextcloud connection..."
    
    response=$(${pkgs.curl}/bin/curl -s -w "%{http_code}" \
      -u "$NEXTCLOUD_USER:$NEXTCLOUD_PASSWORD" \
      "$(webdav_url)" \
      -X PROPFIND)
    
    http_code=$(echo "$response" | tail -c 3)
    
    if [ "$http_code" = "207" ]; then
      success "Connected to Nextcloud"
      log "URL: $NEXTCLOUD_URL"
      log "User: $NEXTCLOUD_USER"
      return 0
    else
      error "Failed to connect (HTTP $http_code)"
      error "Check your credentials and URL"
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
  
  # Create directory if not exists
  ensure_directory() {
    local dir_path="$1"
    ${pkgs.curl}/bin/curl -s -u "$NEXTCLOUD_USER:$NEXTCLOUD_PASSWORD" \
      "$(webdav_url)$dir_path" \
      -X MKCOL 2>/dev/null || true
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
    
    # Ensure base directory exists
    ensure_directory "$NEXTCLOUD_PATH"
    ensure_directory "$NEXTCLOUD_PATH/$session_id"
    
    if [ "$format" = "zip" ] || [ "$format" = "all" ]; then
      log "Creating ZIP archive..."
      local zip_file="$session_dir/$session_id.zip"
      
      if [ ! -f "$zip_file" ]; then
        cd "$session_dir"
        ${pkgs.zip}/bin/zip -r "$zip_file" . -x "*.zip" >/dev/null
        cd - >/dev/null
      fi
      
      log "Uploading ZIP to Nextcloud..."
      ${pkgs.curl}/bin/curl -s -u "$NEXTCLOUD_USER:$NEXTCLOUD_PASSWORD" \
        "$(webdav_url)$NEXTCLOUD_PATH/$session_id/$session_id.zip" \
        -T "$zip_file"
      
      success "ZIP uploaded"
    fi
    
    if [ "$format" = "html" ] || [ "$format" = "all" ]; then
      local html_file="$session_dir/$session_id.html"
      if [ -f "$html_file" ]; then
        log "Uploading HTML..."
        ${pkgs.curl}/bin/curl -s -u "$NEXTCLOUD_USER:$NEXTCLOUD_PASSWORD" \
          "$(webdav_url)$NEXTCLOUD_PATH/$session_id/$session_id.html" \
          -T "$html_file"
        success "HTML uploaded"
      fi
    fi
    
    if [ "$format" = "all" ]; then
      log "Uploading all session files..."
      for file in "$session_dir"/*; do
        [ -f "$file" ] || continue
        filename=$(basename "$file")
        ${pkgs.curl}/bin/curl -s -u "$NEXTCLOUD_USER:$NEXTCLOUD_PASSWORD" \
          "$(webdav_url)$NEXTCLOUD_PATH/$session_id/$filename" \
          -T "$file"
      done
      success "All files uploaded"
    fi
    
    # Create share link if requested
    if [ "$create_share" = "true" ]; then
      log "Creating share link..."
      create_share_link "$session_id"
    fi
    
    success "Upload complete!"
    log "Path: $NEXTCLOUD_PATH/$session_id"
    
    ${pkgs.libnotify}/bin/notify-send "Nextcloud Upload Complete" \
      "Session $session_id uploaded" \
      --icon=dialog-information 2>/dev/null || true
  }
  
  create_share_link() {
    local session_id="$1"
    
    response=$(${pkgs.curl}/bin/curl -s -u "$NEXTCLOUD_USER:$NEXTCLOUD_PASSWORD" \
      -H "OCS-APIRequest: true" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "path=$NEXTCLOUD_PATH/$session_id/$session_id.zip" \
      --data "shareType=3" \
      "$NEXTCLOUD_URL/ocs/v2.php/apps/files_sharing/api/v1/shares?format=json")
    
    share_url=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.ocs.data.url // empty')
    
    if [ -n "$share_url" ]; then
      success "Share link created:"
      echo "$share_url"
    else
      warn "Could not create share link"
    fi
  }
  
  list_sessions() {
    log "Listing sessions in Nextcloud..."
    
    response=$(${pkgs.curl}/bin/curl -s -u "$NEXTCLOUD_USER:$NEXTCLOUD_PASSWORD" \
      "$(webdav_url)$NEXTCLOUD_PATH" \
      -X PROPFIND)
    
    echo "$response" | grep -o '<d:href>[^<]*</d:href>' | \
      sed 's|<d:href>||g; s|</d:href>||g' | \
      grep "$NEXTCLOUD_PATH" | \
      ${pkgs.gawk}/bin/awk -F/ '{print $(NF-1)}' | \
      grep -v "^$" | sort -u
  }
  
  download_session() {
    local session_id="$1"
    log "Downloading session: $session_id"
    
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    local download_dir="$output_dir/$session_id"
    
    mkdir -p "$download_dir"
    
    ${pkgs.curl}/bin/curl -u "$NEXTCLOUD_USER:$NEXTCLOUD_PASSWORD" \
      "$(webdav_url)$NEXTCLOUD_PATH/$session_id/$session_id.zip" \
      -o "$download_dir/$session_id.zip"
    
    cd "$download_dir"
    ${pkgs.unzip}/bin/unzip -q "$session_id.zip"
    rm "$session_id.zip"
    cd - >/dev/null
    
    success "Downloaded to: $download_dir"
  }
  
  delete_session() {
    local session_id="$1"
    log "Deleting session from Nextcloud: $session_id"
    
    read -p "Are you sure? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log "Cancelled"
      exit 0
    fi
    
    ${pkgs.curl}/bin/curl -s -u "$NEXTCLOUD_USER:$NEXTCLOUD_PASSWORD" \
      "$(webdav_url)$NEXTCLOUD_PATH/$session_id" \
      -X DELETE
    
    success "Session deleted from Nextcloud"
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
