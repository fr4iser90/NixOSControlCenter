{ lib, pkgs, cfg }:

# S3 Compatible Cloud Upload
# Works with AWS S3, MinIO, DigitalOcean Spaces, Backblaze B2, etc.

pkgs.writeShellScriptBin "chronicle-s3" ''
  #!/usr/bin/env bash
  set -euo pipefail

  # Configuration
  S3_ENDPOINT="''${S3_ENDPOINT:-}"
  S3_BUCKET="''${S3_BUCKET:-}"
  S3_ACCESS_KEY="''${S3_ACCESS_KEY:-}"
  S3_SECRET_KEY="''${S3_SECRET_KEY:-}"
  S3_REGION="''${S3_REGION:-us-east-1}"
  S3_PREFIX="''${S3_PREFIX:-chronicle}"
  
  usage() {
    cat << EOF
  S3 Cloud Upload for Step Recorder
  
  Usage: chronicle-s3 <command> [options]
  
  Commands:
    upload <session_id>           - Upload session to S3
    upload-auto                   - Upload latest session
    list                          - List uploaded sessions
    download <session_id>         - Download session from S3
    delete <session_id>           - Delete session from S3
    test                          - Test S3 connection
    
  Options:
    --format zip                 - Upload format (zip/html/pdf/all)
    --public                     - Make upload publicly accessible
    --ttl 7d                     - Set expiration (e.g., 7d, 24h, 30m)
    
  Environment Variables:
    S3_ENDPOINT                  - S3 endpoint URL (e.g., https://s3.amazonaws.com)
    S3_BUCKET                    - Bucket name
    S3_ACCESS_KEY                - Access key ID
    S3_SECRET_KEY                - Secret access key
    S3_REGION                    - AWS region (default: us-east-1)
    S3_PREFIX                    - Object key prefix (default: chronicle)
    
  Provider Examples:
    # AWS S3
    export S3_ENDPOINT="https://s3.amazonaws.com"
    export S3_BUCKET="my-recordings"
    export S3_ACCESS_KEY="AKIAIOSFODNN7EXAMPLE"
    export S3_SECRET_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    export S3_REGION="us-west-2"
    
    # MinIO (Self-hosted)
    export S3_ENDPOINT="https://minio.example.com"
    export S3_BUCKET="recordings"
    export S3_ACCESS_KEY="minioadmin"
    export S3_SECRET_KEY="minioadmin"
    
    # DigitalOcean Spaces
    export S3_ENDPOINT="https://nyc3.digitaloceanspaces.com"
    export S3_BUCKET="my-space"
    export S3_REGION="nyc3"
    
    # Backblaze B2
    export S3_ENDPOINT="https://s3.us-west-004.backblazeb2.com"
    export S3_BUCKET="my-bucket"
    
  Usage:
    chronicle-s3 upload-auto --format zip --public
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
    [ -z "$S3_ENDPOINT" ] && { error "S3_ENDPOINT not set"; exit 1; }
    [ -z "$S3_BUCKET" ] && { error "S3_BUCKET not set"; exit 1; }
    [ -z "$S3_ACCESS_KEY" ] && { error "S3_ACCESS_KEY not set"; exit 1; }
    [ -z "$S3_SECRET_KEY" ] && { error "S3_SECRET_KEY not set"; exit 1; }
  }
  
  # Configure AWS CLI
  configure_aws() {
    export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
    export AWS_DEFAULT_REGION="$S3_REGION"
  }
  
  test_connection() {
    log "Testing S3 connection..."
    configure_aws
    
    if ${pkgs.awscli2}/bin/aws s3 ls "s3://$S3_BUCKET" --endpoint-url "$S3_ENDPOINT" &>/dev/null; then
      success "Connected to S3"
      log "Endpoint: $S3_ENDPOINT"
      log "Bucket: $S3_BUCKET"
      log "Region: $S3_REGION"
      return 0
    else
      error "Failed to connect to S3"
      error "Check your credentials and endpoint"
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
  
  upload_session() {
    local session_id="$1"
    local format="''${2:-zip}"
    local make_public="''${3:-false}"
    
    log "Uploading session: $session_id (format: $format)"
    configure_aws
    
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    local session_dir="$output_dir/$session_id"
    
    [ ! -d "$session_dir" ] && { error "Session not found: $session_id"; exit 1; }
    
    local s3_key="$S3_PREFIX/$session_id"
    local acl_flag=""
    [ "$make_public" = "true" ] && acl_flag="--acl public-read"
    
    if [ "$format" = "zip" ] || [ "$format" = "all" ]; then
      log "Creating ZIP archive..."
      local zip_file="$session_dir/$session_id.zip"
      
      if [ ! -f "$zip_file" ]; then
        cd "$session_dir"
        ${pkgs.zip}/bin/zip -r "$zip_file" . -x "*.zip" >/dev/null
        cd - >/dev/null
      fi
      
      log "Uploading ZIP to S3..."
      ${pkgs.awscli2}/bin/aws s3 cp "$zip_file" \
        "s3://$S3_BUCKET/$s3_key/$session_id.zip" \
        --endpoint-url "$S3_ENDPOINT" \
        $acl_flag
      
      success "ZIP uploaded: $s3_key/$session_id.zip"
    fi
    
    if [ "$format" = "html" ] || [ "$format" = "all" ]; then
      local html_file="$session_dir/$session_id.html"
      if [ -f "$html_file" ]; then
        log "Uploading HTML to S3..."
        ${pkgs.awscli2}/bin/aws s3 cp "$html_file" \
          "s3://$S3_BUCKET/$s3_key/$session_id.html" \
          --endpoint-url "$S3_ENDPOINT" \
          --content-type "text/html" \
          $acl_flag
        success "HTML uploaded"
      fi
    fi
    
    if [ "$format" = "all" ]; then
      log "Uploading all session files..."
      ${pkgs.awscli2}/bin/aws s3 sync "$session_dir" \
        "s3://$S3_BUCKET/$s3_key/" \
        --endpoint-url "$S3_ENDPOINT" \
        --exclude "*.zip" \
        $acl_flag
      success "All files uploaded"
    fi
    
    # Generate presigned URL
    local url=$(${pkgs.awscli2}/bin/aws s3 presign \
      "s3://$S3_BUCKET/$s3_key/$session_id.zip" \
      --endpoint-url "$S3_ENDPOINT" \
      --expires-in 604800)  # 7 days
    
    success "Upload complete!"
    log "Download URL (expires in 7 days):"
    echo "$url"
    
    # Send notification
    ${pkgs.libnotify}/bin/notify-send "S3 Upload Complete" \
      "Session $session_id uploaded to S3" \
      --icon=dialog-information 2>/dev/null || true
  }
  
  list_sessions() {
    log "Listing sessions in S3..."
    configure_aws
    
    ${pkgs.awscli2}/bin/aws s3 ls "s3://$S3_BUCKET/$S3_PREFIX/" \
      --endpoint-url "$S3_ENDPOINT" \
      --recursive | grep -E '\.zip$' | \
      ${pkgs.gawk}/bin/awk '{print $4}' | \
      sed "s|$S3_PREFIX/||" | sed 's|/.*||' | sort -u
  }
  
  download_session() {
    local session_id="$1"
    log "Downloading session: $session_id"
    configure_aws
    
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    local download_dir="$output_dir/$session_id"
    
    mkdir -p "$download_dir"
    
    ${pkgs.awscli2}/bin/aws s3 sync \
      "s3://$S3_BUCKET/$S3_PREFIX/$session_id/" \
      "$download_dir" \
      --endpoint-url "$S3_ENDPOINT"
    
    success "Downloaded to: $download_dir"
  }
  
  delete_session() {
    local session_id="$1"
    log "Deleting session from S3: $session_id"
    configure_aws
    
    read -p "Are you sure? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log "Cancelled"
      exit 0
    fi
    
    ${pkgs.awscli2}/bin/aws s3 rm \
      "s3://$S3_BUCKET/$S3_PREFIX/$session_id/" \
      --endpoint-url "$S3_ENDPOINT" \
      --recursive
    
    success "Session deleted from S3"
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
    test)
      check_requirements
      test_connection
      ;;
    help|*)
      usage
      ;;
  esac
''
