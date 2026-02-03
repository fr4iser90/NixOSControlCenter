{ lib, pkgs, cfg }:

# GitLab Issues Integration - Automatic issue creation
# Similar to GitHub but for GitLab

pkgs.writeShellScriptBin "chronicle-gitlab" ''
  #!/usr/bin/env bash
  set -euo pipefail

  # Configuration
  GITLAB_TOKEN="''${GITLAB_TOKEN:-}"
  GITLAB_PROJECT="''${GITLAB_PROJECT:-}"  # Format: project_id or group/project
  GITLAB_URL="''${GITLAB_URL:-https://gitlab.com}"
  GITLAB_API="$GITLAB_URL/api/v4"
  
  usage() {
    cat << EOF
  GitLab Issues Integration for Step Recorder
  
  Usage: chronicle-gitlab <command> [options]
  
  Commands:
    create <session_id>           - Create issue from session
    create-auto                   - Create issue from latest session
    test                          - Test GitLab API connection
    
  Options:
    --title "title"              - Issue title (default: session title)
    --labels "bug,help wanted"   - Comma-separated labels
    --assignee user_id           - Assign to user (use ID)
    --milestone milestone_id     - Assign to milestone (use ID)
    
  Environment Variables:
    GITLAB_TOKEN                 - GitLab Personal/Project Access Token
    GITLAB_PROJECT               - Project ID or group/project path
    GITLAB_URL                   - GitLab instance URL (default: https://gitlab.com)
    
  Examples:
    # For gitlab.com
    export GITLAB_TOKEN="glpat-xxxxxxxxxxxx"
    export GITLAB_PROJECT="mygroup/myproject"
    
    # For self-hosted GitLab
    export GITLAB_URL="https://gitlab.example.com"
    export GITLAB_TOKEN="glpat-xxxxxxxxxxxx"
    export GITLAB_PROJECT="42"  # Project ID
    
    # Create issue
    chronicle-gitlab create-auto --labels "bug,recording"
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
    [ -z "$GITLAB_TOKEN" ] && { error "GITLAB_TOKEN not set"; exit 1; }
    [ -z "$GITLAB_PROJECT" ] && { error "GITLAB_PROJECT not set"; exit 1; }
  }
  
  # URL encode project path
  urlencode() {
    echo "$1" | ${pkgs.curl}/bin/curl -Gso /dev/null -w %{url_effective} --data-urlencode @- "" | cut -c 3-
  }
  
  test_connection() {
    log "Testing GitLab API connection..."
    local encoded_project=$(urlencode "$GITLAB_PROJECT")
    
    response=$(${pkgs.curl}/bin/curl -s -w "\n%{http_code}" \
      -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
      "$GITLAB_API/projects/$encoded_project")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
      proj_name=$(echo "$body" | ${pkgs.jq}/bin/jq -r '.name')
      proj_namespace=$(echo "$body" | ${pkgs.jq}/bin/jq -r '.namespace.full_path')
      success "Connected to GitLab"
      log "Project: $proj_namespace/$proj_name"
      log "URL: $GITLAB_URL"
      return 0
    else
      error "GitLab API error (HTTP $http_code)"
      echo "$body" | ${pkgs.jq}/bin/jq -r '.message // "Unknown error"'
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
    local labels="''${3:-}"
    
    log "Creating GitLab issue for session: $session_id"
    
    local metadata=$(load_session_metadata "$session_id")
    local session_title=$(echo "$metadata" | ${pkgs.jq}/bin/jq -r '.title // "Recording Session"')
    local session_desc=$(echo "$metadata" | ${pkgs.jq}/bin/jq -r '.description // ""')
    local started_at=$(echo "$metadata" | ${pkgs.jq}/bin/jq -r '.started_at')
    local step_count=$(echo "$metadata" | ${pkgs.jq}/bin/jq -r '.step_count // 0')
    
    [ -n "$title" ] && session_title="$title"
    
    local body="## 🎬 Recording Session Report

  **Session ID:** \`$session_id\`  
  **Recorded:** $started_at  
  **Steps:** $step_count

  ### Description

  $session_desc

  ---
  *Created by NixOS Step Recorder v${cfg._version}*"
    
    local payload=$(${pkgs.jq}/bin/jq -n \
      --arg title "$session_title" \
      --arg desc "$body" \
      '{title: $title, description: $desc}')
    
    if [ -n "$labels" ]; then
      payload=$(echo "$payload" | ${pkgs.jq}/bin/jq --arg labels "$labels" '. + {labels: $labels}')
    fi
    
    local encoded_project=$(urlencode "$GITLAB_PROJECT")
    
    response=$(${pkgs.curl}/bin/curl -s -w "\n%{http_code}" \
      -X POST \
      -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "$GITLAB_API/projects/$encoded_project/issues")
    
    http_code=$(echo "$response" | tail -n1)
    body_response=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "201" ]; then
      issue_iid=$(echo "$body_response" | ${pkgs.jq}/bin/jq -r '.iid')
      issue_url=$(echo "$body_response" | ${pkgs.jq}/bin/jq -r '.web_url')
      
      success "Issue created: #$issue_iid"
      log "URL: $issue_url"
      
      ${pkgs.libnotify}/bin/notify-send "GitLab Issue Created" \
        "Issue #$issue_iid created" --icon=dialog-information 2>/dev/null || true
      
      echo "$issue_url"
      return 0
    else
      error "Failed to create issue (HTTP $http_code)"
      echo "$body_response" | ${pkgs.jq}/bin/jq -r '.message // "Unknown error"'
      exit 1
    fi
  }
  
  case "''${1:-help}" in
    create)
      [ -z "''${2:-}" ] && { error "Session ID required"; exit 1; }
      check_requirements
      test_connection > /dev/null
      create_issue "$2" "''${3:-}" "''${4:-}"
      ;;
    create-auto)
      check_requirements
      test_connection > /dev/null
      session_id=$(get_latest_session)
      log "Using latest session: $session_id"
      create_issue "$session_id" "''${2:-}" "''${3:-}"
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
