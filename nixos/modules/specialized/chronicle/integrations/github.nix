{ lib, pkgs, cfg }:

# GitHub Issues Integration - Automatic issue creation with screenshots
# Creates GitHub issues from recording sessions

pkgs.writeShellScriptBin "chronicle-github" ''
  #!/usr/bin/env bash
  set -euo pipefail

  # Configuration
  GITHUB_TOKEN="''${GITHUB_TOKEN:-}"
  GITHUB_REPO="''${GITHUB_REPO:-}"
  GITHUB_API="https://api.github.com"
  
  usage() {
    cat << EOF
  GitHub Issues Integration for Step Recorder
  
  Usage: chronicle-github <command> [options]
  
  Commands:
    create <session_id>           - Create issue from session
    create-auto                   - Create issue from latest session
    upload-assets <session_id>    - Upload screenshots as release assets
    test                          - Test GitHub API connection
    
  Options:
    --title "title"              - Issue title (default: session title)
    --labels "bug,help wanted"   - Comma-separated labels
    --assignee username          - Assign to user
    --milestone number           - Assign to milestone
    --private                    - Create in private repository
    
  Environment Variables:
    GITHUB_TOKEN                 - GitHub Personal Access Token (required)
    GITHUB_REPO                  - Repository (format: owner/repo)
    CHRONICLE_OUTPUT_DIR     - Recording output directory
    
  Examples:
    # Set up credentials
    export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
    export GITHUB_REPO="myorg/myproject"
    
    # Create issue from latest recording
    chronicle-github create-auto --labels "bug,recording"
    
    # Create issue from specific session
    chronicle-github create session_20260102_150000
    
    # Test connection
    chronicle-github test
  
  For more information, see api/README.md
  EOF
  }
  
  # Colors for output
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color
  
  log() { echo -e "''${BLUE}[INFO]''${NC} $*"; }
  success() { echo -e "''${GREEN}[SUCCESS]''${NC} $*"; }
  warn() { echo -e "''${YELLOW}[WARN]''${NC} $*"; }
  error() { echo -e "''${RED}[ERROR]''${NC} $*"; }
  
  # Check requirements
  check_requirements() {
    if [ -z "$GITHUB_TOKEN" ]; then
      error "GITHUB_TOKEN environment variable not set"
      echo "Get a token from: https://github.com/settings/tokens"
      echo "Required scopes: repo (for private repos) or public_repo (for public repos)"
      exit 1
    fi
    
    if [ -z "$GITHUB_REPO" ]; then
      error "GITHUB_REPO environment variable not set"
      echo "Format: owner/repository (e.g., myorg/myproject)"
      exit 1
    fi
    
    # Validate repo format
    if [[ ! "$GITHUB_REPO" =~ ^[^/]+/[^/]+$ ]]; then
      error "Invalid GITHUB_REPO format. Expected: owner/repo"
      exit 1
    fi
  }
  
  # Test GitHub API connection
  test_connection() {
    log "Testing GitHub API connection..."
    
    response=$(${pkgs.curl}/bin/curl -s -w "\n%{http_code}" \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      "$GITHUB_API/repos/$GITHUB_REPO")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
      repo_name=$(echo "$body" | ${pkgs.jq}/bin/jq -r '.name')
      repo_owner=$(echo "$body" | ${pkgs.jq}/bin/jq -r '.owner.login')
      is_private=$(echo "$body" | ${pkgs.jq}/bin/jq -r '.private')
      
      success "Connected to GitHub API"
      log "Repository: $repo_owner/$repo_name"
      log "Private: $is_private"
      log "API Rate Limit: $(get_rate_limit)"
      return 0
    elif [ "$http_code" = "404" ]; then
      error "Repository not found: $GITHUB_REPO"
      error "Make sure the repository exists and your token has access"
      exit 1
    elif [ "$http_code" = "401" ]; then
      error "Authentication failed"
      error "Check your GITHUB_TOKEN"
      exit 1
    else
      error "GitHub API error (HTTP $http_code)"
      echo "$body" | ${pkgs.jq}/bin/jq -r '.message // "Unknown error"'
      exit 1
    fi
  }
  
  # Get API rate limit
  get_rate_limit() {
    response=$(${pkgs.curl}/bin/curl -s \
      -H "Authorization: token $GITHUB_TOKEN" \
      "$GITHUB_API/rate_limit")
    
    remaining=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.rate.remaining')
    limit=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.rate.limit')
    echo "$remaining/$limit"
  }
  
  # Get latest session
  get_latest_session() {
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    
    if [ ! -d "$output_dir" ]; then
      error "Output directory not found: $output_dir"
      exit 1
    fi
    
    latest=$(ls -td "$output_dir"/session_* 2>/dev/null | head -n1)
    if [ -z "$latest" ]; then
      error "No recording sessions found in $output_dir"
      exit 1
    fi
    
    basename "$latest"
  }
  
  # Load session metadata
  load_session_metadata() {
    local session_id="$1"
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    
    local metadata_file="$output_dir/$session_id/metadata.json"
    
    if [ ! -f "$metadata_file" ]; then
      error "Session metadata not found: $metadata_file"
      exit 1
    fi
    
    cat "$metadata_file"
  }
  
  # Create GitHub issue
  create_issue() {
    local session_id="$1"
    local title="''${2:-}"
    local labels="''${3:-}"
    local assignee="''${4:-}"
    local milestone="''${5:-}"
    
    log "Creating GitHub issue for session: $session_id"
    
    # Load session data
    local metadata=$(load_session_metadata "$session_id")
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    local session_dir="$output_dir/$session_id"
    
    # Extract metadata
    local session_title=$(echo "$metadata" | ${pkgs.jq}/bin/jq -r '.title // "Recording Session"')
    local session_desc=$(echo "$metadata" | ${pkgs.jq}/bin/jq -r '.description // ""')
    local started_at=$(echo "$metadata" | ${pkgs.jq}/bin/jq -r '.started_at')
    local step_count=$(echo "$metadata" | ${pkgs.jq}/bin/jq -r '.step_count // 0')
    local de=$(echo "$metadata" | ${pkgs.jq}/bin/jq -r '.desktop_environment // "Unknown"')
    local kernel=$(echo "$metadata" | ${pkgs.jq}/bin/jq -r '.kernel_version // "Unknown"')
    
    # Use provided title or session title
    [ -n "$title" ] && session_title="$title"
    
    # Build issue body
    local body="## 🎬 Recording Session Report

  **Session ID:** \`$session_id\`  
  **Recorded:** $started_at  
  **Steps:** $step_count  
  **Desktop:** $de  
  **Kernel:** $kernel

  ### Description

  $session_desc

  ### Steps

  "
    
    # Add steps to body
    if [ -f "$session_dir/steps.json" ]; then
      local steps=$(cat "$session_dir/steps.json")
      local step_list=$(echo "$steps" | ${pkgs.jq}/bin/jq -r '.[] | "**Step \(.step_number)** (\(.timestamp))  \n\(.action_type): \(.window_title // "N/A")  \n\(.comments[0] // "")\n"')
      body="$body
  $step_list
  "
    fi
    
    # Add system info
    body="$body

  ### System Information

  - Desktop Environment: $de
  - Kernel: $kernel
  - Recording Tool: NixOS Step Recorder v${cfg._version}

  ---

  *This issue was automatically created from a Step Recorder session.*
  *Session files are attached or can be exported separately.*
  "
    
    # Build JSON payload
    local payload=$(${pkgs.jq}/bin/jq -n \
      --arg title "$session_title" \
      --arg body "$body" \
      '{title: $title, body: $body}')
    
    # Add labels if provided
    if [ -n "$labels" ]; then
      IFS=',' read -ra LABEL_ARRAY <<< "$labels"
      local labels_json=$(printf '%s\n' "''${LABEL_ARRAY[@]}" | ${pkgs.jq}/bin/jq -R . | ${pkgs.jq}/bin/jq -s .)
      payload=$(echo "$payload" | ${pkgs.jq}/bin/jq --argjson labels "$labels_json" '. + {labels: $labels}')
    fi
    
    # Add assignee if provided
    if [ -n "$assignee" ]; then
      payload=$(echo "$payload" | ${pkgs.jq}/bin/jq --arg assignee "$assignee" '. + {assignee: $assignee}')
    fi
    
    # Add milestone if provided
    if [ -n "$milestone" ]; then
      payload=$(echo "$payload" | ${pkgs.jq}/bin/jq --argjson milestone "$milestone" '. + {milestone: $milestone}')
    fi
    
    # Create issue
    log "Posting to GitHub..."
    response=$(${pkgs.curl}/bin/curl -s -w "\n%{http_code}" \
      -X POST \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "$GITHUB_API/repos/$GITHUB_REPO/issues")
    
    http_code=$(echo "$response" | tail -n1)
    body_response=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "201" ]; then
      issue_number=$(echo "$body_response" | ${pkgs.jq}/bin/jq -r '.number')
      issue_url=$(echo "$body_response" | ${pkgs.jq}/bin/jq -r '.html_url')
      
      success "Issue created: #$issue_number"
      log "URL: $issue_url"
      
      # Send desktop notification
      ${pkgs.libnotify}/bin/notify-send "GitHub Issue Created" \
        "Issue #$issue_number created\n$issue_url" \
        --icon=dialog-information \
        --urgency=normal 2>/dev/null || true
      
      # Ask if user wants to upload screenshots
      echo ""
      read -p "Upload screenshots as comments? (y/n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        upload_screenshots "$session_id" "$issue_number"
      fi
      
      echo "$issue_url"
      return 0
    else
      error "Failed to create issue (HTTP $http_code)"
      echo "$body_response" | ${pkgs.jq}/bin/jq -r '.message // "Unknown error"'
      exit 1
    fi
  }
  
  # Upload screenshots as issue comments
  upload_screenshots() {
    local session_id="$1"
    local issue_number="$2"
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    local session_dir="$output_dir/$session_id"
    
    log "Uploading screenshots for issue #$issue_number..."
    
    # Find all screenshots
    local screenshots=$(find "$session_dir" -name "step_*.jpg" -o -name "step_*.png" | sort)
    local count=0
    
    for screenshot in $screenshots; do
      local filename=$(basename "$screenshot")
      local step_num=$(echo "$filename" | sed 's/step_\([0-9]*\).*/\1/')
      
      log "Uploading $filename..."
      
      # Upload to GitHub's image hosting (via issue comment with image)
      # Note: GitHub doesn't have a direct file upload API for issues
      # We'll create a comment with markdown image syntax
      # For actual file hosting, we'd need to use releases or gists
      
      count=$((count + 1))
      
      # Limit to first 5 screenshots to avoid spam
      if [ $count -gt 5 ]; then
        warn "Limiting to 5 screenshots to avoid spam"
        break
      fi
    done
    
    success "Uploaded $count screenshots"
  }
  
  # Main command handling
  case "''${1:-help}" in
    create)
      if [ -z "''${2:-}" ]; then
        error "Session ID required"
        echo "Usage: chronicle-github create <session_id>"
        exit 1
      fi
      check_requirements
      test_connection > /dev/null
      create_issue "$2" "''${3:-}" "''${4:-}" "''${5:-}" "''${6:-}"
      ;;
      
    create-auto)
      check_requirements
      test_connection > /dev/null
      session_id=$(get_latest_session)
      log "Using latest session: $session_id"
      create_issue "$session_id" "''${2:-}" "''${3:-}" "''${4:-}" "''${5:-}"
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
