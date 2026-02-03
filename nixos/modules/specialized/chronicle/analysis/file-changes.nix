{ lib, pkgs, cfg }:

# File Changes Tracking - inotify + git integration

pkgs.writeShellScriptBin "chronicle-files" ''
  #!/usr/bin/env bash
  set -euo pipefail

  usage() {
    cat << EOF
  File Changes Tracking for Step Recorder
  
  Usage: chronicle-files <command> [options]
  
  Commands:
    watch <path> <session_id>    - Watch directory for changes
    diff <session_id>            - Show file changes during session
    git-diff <session_id>        - Show git changes if in repo
  EOF
  }
  
  watch_directory() {
    local watch_path="$1"
    local session_id="$2"
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    local changes_file="$output_dir/$session_id/file-changes.log"
    
    ${pkgs.inotify-tools}/bin/inotifywait -m -r \
      -e modify,create,delete,move \
      --format '%T %e %w%f' \
      --timefmt '%Y-%m-%d %H:%M:%S' \
      "$watch_path" >> "$changes_file" &
    
    echo $! > "$output_dir/$session_id/file-watcher.pid"
    echo "Watching $watch_path (PID: $!)"
  }
  
  show_diff() {
    local session_id="$1"
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    
    if [ -f "$output_dir/$session_id/file-changes.log" ]; then
      cat "$output_dir/$session_id/file-changes.log"
    else
      echo "No file changes tracked"
    fi
  }
  
  git_diff() {
    local session_id="$1"
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    local session_dir="$output_dir/$session_id"
    
    # Get session timeframe
    local start_time=$(${pkgs.jq}/bin/jq -r '.started_at' "$session_dir/metadata.json")
    
    # Find git repositories and get recent changes
    ${pkgs.git}/bin/git --no-pager log \
      --since="$start_time" \
      --pretty=format:"%h - %an, %ar : %s" \
      > "$session_dir/git-changes.log" 2>/dev/null || \
      echo "Not in a git repository"
    
    cat "$session_dir/git-changes.log"
  }
  
  case "''${1:-help}" in
    watch) watch_directory "$2" "$3" ;;
    diff) show_diff "$2" ;;
    git-diff) git_diff "$2" ;;
    help|*) usage ;;
  esac
''
