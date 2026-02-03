{ lib, pkgs, cfg }:

# System Logs Integration - journalctl correlation

pkgs.writeShellScriptBin "chronicle-logs" ''
  #!/usr/bin/env bash
  set -euo pipefail

  usage() {
    cat << EOF
  System Logs Integration for Step Recorder
  
  Usage: chronicle-logs <command> [options]
  
  Commands:
    correlate <session_id>       - Correlate logs with session
    errors <session_id>          - Extract errors during session
    timeline <session_id>        - Create log timeline
  EOF
  }
  
  correlate_logs() {
    local session_id="$1"
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    local session_dir="$output_dir/$session_id"
    
    # Get session timeframe
    local start_time=$(${pkgs.jq}/bin/jq -r '.started_at' "$session_dir/metadata.json")
    local end_time=$(${pkgs.jq}/bin/jq -r '.stopped_at // now' "$session_dir/metadata.json")
    
    # Extract relevant logs
    ${pkgs.systemd}/bin/journalctl \
      --since="$start_time" \
      --until="$end_time" \
      --priority=warning \
      --output=json > "$session_dir/system-logs.json"
    
    echo "Logs extracted: $session_dir/system-logs.json"
  }
  
  extract_errors() {
    local session_id="$1"
    local output_dir="''${CHRONICLE_OUTPUT_DIR:-${cfg.outputDir}}"
    eval output_dir="$output_dir"
    
    correlate_logs "$session_id"
    
    ${pkgs.jq}/bin/jq -r '.MESSAGE' \
      "$output_dir/$session_id/system-logs.json" | \
      grep -i error || echo "No errors found"
  }
  
  case "''${1:-help}" in
    correlate) correlate_logs "$2" ;;
    errors) extract_errors "$2" ;;
    help|*) usage ;;
  esac
''
