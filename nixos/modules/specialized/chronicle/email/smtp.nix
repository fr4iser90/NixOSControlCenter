{ lib, pkgs, cfg }:

# Email Integration - SMTP with attachments
# Send recording sessions via email with ZIP/PDF attachments

pkgs.writeShellScriptBin "chronicle-email" ''
  #!/usr/bin/env bash
  set -euo pipefail

  # Configuration
  SMTP_HOST="''${SMTP_HOST:-}"
  SMTP_PORT="''${SMTP_PORT:-587}"
  SMTP_USER="''${SMTP_USER:-}"
  SMTP_PASSWORD="''${SMTP_PASSWORD:-}"
  SMTP_FROM="''${SMTP_FROM:-$SMTP_USER}"
  SMTP_TLS="''${SMTP_TLS:-true}"
  
  usage() {
    cat << EOF
  Email Integration for Step Recorder
  
  Usage: chronicle-email <command> [options]
  
  Commands:
    send <session_id> <to>        - Send session via email
    send-auto <to>                - Send latest session
    test                          - Test SMTP connection
    
  Options:
    --subject "Subject"          - Email subject
    --body "Message"             - Email body
    --format zip                 - Attachment format (zip/pdf/both)
    --cc email@example.com       - CC recipients (comma-separated)
    
  Environment Variables:
    SMTP_HOST                    - SMTP server (e.g., smtp.gmail.com)
    SMTP_PORT                    - SMTP port (default: 587)
    SMTP_USER                    - SMTP username
    SMTP_PASSWORD                - SMTP password/app password
    SMTP_FROM                    - From address (default: SMTP_USER)
    SMTP_TLS                     - Use TLS (default: true)
    
  Examples:
    # Gmail
    export SMTP_HOST="smtp.gmail.com"
    export SMTP_PORT="587"
    export SMTP_USER="you@gmail.com"
    export SMTP_PASSWORD="app-password"
    
    chronicle-email send-auto user@example.com --format both
  EOF
  }
  
  # Colors
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  BLUE='\033[0;34m'
  NC='\033[0m'
  
  log() { echo -e "''${BLUE}[INFO]''${NC} $*"; }
  success() { echo -e "''${GREEN}[SUCCESS]''${NC} $*"; }
  error() { echo -e "''${RED}[ERROR]''${NC} $*"; }
  
  check_requirements() {
    [ -z "$SMTP_HOST" ] && { error "SMTP_HOST not set"; exit 1; }
    [ -z "$SMTP_USER" ] && { error "SMTP_USER not set"; exit 1; }
    [ -z "$SMTP_PASSWORD" ] && { error "SMTP_PASSWORD not set"; exit 1; }
  }
  
  test_connection() {
    log "Testing SMTP connection..."
    
    ${pkgs.curl}/bin/curl -s --url "smtp://$SMTP_HOST:$SMTP_PORT" \
      --mail-from "$SMTP_FROM" \
      --mail-rcpt "$SMTP_USER" \
      --user "$SMTP_USER:$SMTP_PASSWORD" \
      --upload-file <(echo "Subject: Test\n\nTest") 2>&1 | grep -q "250" && \
      success "SMTP connection successful" || \
      { error "SMTP connection failed"; exit 1; }
  }
  
  get_latest_session() {
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    latest=$(ls -td "$output_dir"/session_* 2>/dev/null | head -n1)
    [ -z "$latest" ] && { error "No sessions found"; exit 1; }
    basename "$latest"
  }
  
  send_email() {
    local session_id="$1"
    local to="$2"
    local subject="''${3:-Recording Session: $session_id}"
    local body="''${4:-Please find the attached recording session.}"
    local format="''${5:-zip}"
    local cc="''${6:-}"
    
    log "Sending email to: $to"
    
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    local session_dir="$output_dir/$session_id"
    
    [ ! -d "$session_dir" ] && { error "Session not found"; exit 1; }
    
    # Create temp email file
    local email_file=$(mktemp)
    local boundary="----=_NextPart_$(date +%s)"
    
    # Email headers
    cat > "$email_file" << HEADERS
From: $SMTP_FROM
To: $to
HEADERS
    
    [ -n "$cc" ] && echo "Cc: $cc" >> "$email_file"
    
    cat >> "$email_file" << HEADERS
Subject: $subject
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="$boundary"

--$boundary
Content-Type: text/html; charset=UTF-8

<html><body>
<h2>Recording Session Report</h2>
<p>$body</p>
<p><strong>Session ID:</strong> $session_id</p>
<p>Files are attached to this email.</p>
</body></html>

HEADERS
    
    # Attach ZIP
    if [ "$format" = "zip" ] || [ "$format" = "both" ]; then
      local zip_file="$session_dir/$session_id.zip"
      if [ ! -f "$zip_file" ]; then
        cd "$session_dir"
        ${pkgs.zip}/bin/zip -r "$zip_file" . -x "*.zip" >/dev/null
        cd - >/dev/null
      fi
      
      echo "--$boundary" >> "$email_file"
      echo "Content-Type: application/zip; name=\"$session_id.zip\"" >> "$email_file"
      echo "Content-Transfer-Encoding: base64" >> "$email_file"
      echo "Content-Disposition: attachment; filename=\"$session_id.zip\"" >> "$email_file"
      echo "" >> "$email_file"
      ${pkgs.coreutils}/bin/base64 "$zip_file" >> "$email_file"
      echo "" >> "$email_file"
    fi
    
    # End boundary
    echo "--$boundary--" >> "$email_file"
    
    # Send email
    ${pkgs.curl}/bin/curl -s --url "smtp://$SMTP_HOST:$SMTP_PORT" \
      --mail-from "$SMTP_FROM" \
      --mail-rcpt "$to" \
      $([ -n "$cc" ] && echo "--mail-rcpt $cc") \
      --user "$SMTP_USER:$SMTP_PASSWORD" \
      --upload-file "$email_file" \
      $([ "$SMTP_TLS" = "true" ] && echo "--ssl-reqd")
    
    rm "$email_file"
    
    success "Email sent to $to"
    
    ${pkgs.libnotify}/bin/notify-send "Email Sent" \
      "Session $session_id sent to $to" \
      --icon=dialog-information 2>/dev/null || true
  }
  
  case "''${1:-help}" in
    send)
      [ -z "''${2:-}" ] && { error "Session ID required"; exit 1; }
      [ -z "''${3:-}" ] && { error "Recipient required"; exit 1; }
      check_requirements
      send_email "$2" "$3" "''${4:-}" "''${5:-}" "''${6:-zip}" "''${7:-}"
      ;;
    send-auto)
      [ -z "''${2:-}" ] && { error "Recipient required"; exit 1; }
      check_requirements
      session_id=$(get_latest_session)
      log "Using latest session: $session_id"
      send_email "$session_id" "$2" "''${3:-}" "''${4:-}" "''${5:-zip}" "''${6:-}"
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
