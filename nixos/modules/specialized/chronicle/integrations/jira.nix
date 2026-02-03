{ lib, pkgs, cfg }:

# JIRA Integration - Create JIRA tickets from recording sessions

pkgs.writeShellScriptBin "chronicle-jira" ''
  #!/usr/bin/env bash
  set -euo pipefail

  # Configuration
  JIRA_URL="''${JIRA_URL:-}"
  JIRA_USER="''${JIRA_USER:-}"
  JIRA_TOKEN="''${JIRA_TOKEN:-}"
  JIRA_PROJECT="''${JIRA_PROJECT:-}"
  
  usage() {
    cat << EOF
  JIRA Integration for Step Recorder
  
  Usage: chronicle-jira <command> [options]
  
  Commands:
    create <session_id>           - Create JIRA ticket from session
    create-auto                   - Create ticket from latest session
    test                          - Test JIRA API connection
    
  Options:
    --title "title"              - Ticket summary (default: session title)
    --type Bug                   - Issue type (Bug, Task, Story, etc.)
    --priority High              - Priority (Highest, High, Medium, Low, Lowest)
    --assignee username          - Assign to user
    --labels "bug,recording"     - Comma-separated labels
    
  Environment Variables:
    JIRA_URL                     - JIRA instance URL (e.g., https://company.atlassian.net)
    JIRA_USER                    - JIRA username/email
    JIRA_TOKEN                   - JIRA API token
    JIRA_PROJECT                 - Project key (e.g., PROJ)
    
  Examples:
    # Set up JIRA credentials
    export JIRA_URL="https://mycompany.atlassian.net"
    export JIRA_USER="user@company.com"
    export JIRA_TOKEN="ATATTxxxxxxxx"
    export JIRA_PROJECT="BUGTRACK"
    
    # Create ticket
    chronicle-jira create-auto --type Bug --priority High
    
    # Test connection
    chronicle-jira test
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
    [ -z "$JIRA_URL" ] && { error "JIRA_URL not set"; exit 1; }
    [ -z "$JIRA_USER" ] && { error "JIRA_USER not set"; exit 1; }
    [ -z "$JIRA_TOKEN" ] && { error "JIRA_TOKEN not set"; exit 1; }
    [ -z "$JIRA_PROJECT" ] && { error "JIRA_PROJECT not set"; exit 1; }
  }
  
  test_connection() {
    log "Testing JIRA API connection..."
    
    response=$(${pkgs.curl}/bin/curl -s -w "\n%{http_code}" \
      -u "$JIRA_USER:$JIRA_TOKEN" \
      -H "Accept: application/json" \
      "$JIRA_URL/rest/api/3/myself")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
      username=$(echo "$body" | ${pkgs.jq}/bin/jq -r '.displayName')
      email=$(echo "$body" | ${pkgs.jq}/bin/jq -r '.emailAddress')
      success "Connected to JIRA"
      log "User: $username ($email)"
      log "Instance: $JIRA_URL"
      return 0
    else
      error "JIRA API error (HTTP $http_code)"
      echo "$body" | ${pkgs.jq}/bin/jq -r '.errorMessages[]? // "Unknown error"'
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
  
  load_session_metadata() {
    local session_id="$1"
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    cat "$output_dir/$session_id/metadata.json"
  }
  
  create_issue() {
    local session_id="$1"
    local title="''${2:-}"
    local issue_type="''${3:-Bug}"
    local priority="''${4:-Medium}"
    
    log "Creating JIRA ticket for session: $session_id"
    
    local metadata=$(load_session_metadata "$session_id")
    local session_title=$(echo "$metadata" | ${pkgs.jq}/bin/jq -r '.title // "Recording Session"')
    local session_desc=$(echo "$metadata" | ${pkgs.jq}/bin/jq -r '.description // ""')
    local started_at=$(echo "$metadata" | ${pkgs.jq}/bin/jq -r '.started_at')
    local step_count=$(echo "$metadata" | ${pkgs.jq}/bin/jq -r '.step_count // 0')
    
    [ -n "$title" ] && session_title="$title"
    
    # JIRA uses ADF (Atlassian Document Format) for rich text
    local description="h2. Recording Session Report

  *Session ID:* {code}$session_id{code}
  *Recorded:* $started_at
  *Steps:* $step_count

  h3. Description

  $session_desc

  ----
  _Created by NixOS Step Recorder v${cfg._version}_"
    
    local payload=$(${pkgs.jq}/bin/jq -n \
      --arg project "$JIRA_PROJECT" \
      --arg summary "$session_title" \
      --arg description "$description" \
      --arg issuetype "$issue_type" \
      '{
        fields: {
          project: { key: $project },
          summary: $summary,
          description: $description,
          issuetype: { name: $issuetype }
        }
      }')
    
    response=$(${pkgs.curl}/bin/curl -s -w "\n%{http_code}" \
      -X POST \
      -u "$JIRA_USER:$JIRA_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "$JIRA_URL/rest/api/3/issue")
    
    http_code=$(echo "$response" | tail -n1)
    body_response=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "201" ]; then
      issue_key=$(echo "$body_response" | ${pkgs.jq}/bin/jq -r '.key')
      issue_id=$(echo "$body_response" | ${pkgs.jq}/bin/jq -r '.id')
      issue_url="$JIRA_URL/browse/$issue_key"
      
      success "JIRA ticket created: $issue_key"
      log "URL: $issue_url"
      
      ${pkgs.libnotify}/bin/notify-send "JIRA Ticket Created" \
        "Ticket $issue_key created" --icon=dialog-information 2>/dev/null || true
      
      echo "$issue_url"
      return 0
    else
      error "Failed to create ticket (HTTP $http_code)"
      echo "$body_response" | ${pkgs.jq}/bin/jq -r '.errorMessages[]? // .errors? // "Unknown error"'
      exit 1
    fi
  }
  
  case "''${1:-help}" in
    create)
      [ -z "''${2:-}" ] && { error "Session ID required"; exit 1; }
      check_requirements
      test_connection > /dev/null
      create_issue "$2" "''${3:-}" "''${4:-}" "''${5:-}"
      ;;
    create-auto)
      check_requirements
      test_connection > /dev/null
      session_id=$(get_latest_session)
      log "Using latest session: $session_id"
      create_issue "$session_id" "''${2:-}" "''${3:-}" "''${4:-}"
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
