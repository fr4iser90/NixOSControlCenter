{ lib, pkgs, cfg }:

{
  # Export all formats functionality
  exportAll = ''
    # Export recording in all formats
    export_all_formats() {
      local session_path="$1"
      local session_id=$(basename "$session_path")
      
      log "📦 Exporting all formats for: $session_id"
      
      # Export to each format
      local formats=("html" "markdown" "json" "zip")
      local export_results=()
      
      for format in "''${formats[@]}"; do
        log "Exporting to $format..."
        
        case "$format" in
          html)
            if export_html "$session_path"; then
              export_results+=("✅ HTML: $session_path/report.html")
            else
              export_results+=("❌ HTML: failed")
            fi
            ;;
          markdown)
            if export_markdown "$session_path"; then
              export_results+=("✅ Markdown: $session_path/report.md")
            else
              export_results+=("❌ Markdown: failed")
            fi
            ;;
          json)
            if export_json "$session_path"; then
              export_results+=("✅ JSON: $session_path/report.json")
            else
              export_results+=("❌ JSON: failed")
            fi
            ;;
          zip)
            if export_zip "$session_path"; then
              export_results+=("✅ ZIP: $session_path.zip")
            else
              export_results+=("❌ ZIP: failed")
            fi
            ;;
        esac
      done
      
      # Display results
      log "Export complete!"
      for result in "''${export_results[@]}"; do
        echo "  $result"
      done
      
      # Send notification
      notify_export_completed "$session_id" "all" "$session_path"
    }
    
    # Quick export command
    quick_export_all() {
      load_state || {
        # No active recording, try to find most recent session
        local latest_session=$(find "$OUTPUT_DIR" -maxdepth 1 -type d -name "session_*" 2>/dev/null | sort -r | head -n1)
        
        if [ -z "$latest_session" ]; then
          error "No sessions found to export"
          return 1
        fi
        
        export_all_formats "$latest_session"
        return 0
      }
      
      # Export current session
      if [ "$RECORDING" = "true" ]; then
        warn "Recording is still active. Stop recording first."
        return 1
      fi
      
      export_all_formats "$OUTPUT_DIR/$SESSION_ID"
    }
  '';
  
  # Auto-open report functionality
  autoOpen = ''
    # Auto-open generated report in default browser/viewer
    auto_open_report() {
      local session_path="$1"
      local format="''${2:-html}"
      
      local report_file=""
      case "$format" in
        html)
          report_file="$session_path/report.html"
          ;;
        markdown)
          report_file="$session_path/report.md"
          ;;
        json)
          report_file="$session_path/report.json"
          ;;
      esac
      
      if [ ! -f "$report_file" ]; then
        warn "Report file not found: $report_file"
        return 1
      fi
      
      # Try to open with default application
      if command -v xdg-open &> /dev/null; then
        ${pkgs.xdg-utils}/bin/xdg-open "$report_file" &>/dev/null &
        log "📖 Opening report: $report_file"
      elif command -v open &> /dev/null; then
        open "$report_file" &>/dev/null &
        log "📖 Opening report: $report_file"
      else
        log "Report saved: $report_file"
        log "Open manually with your browser/viewer"
      fi
    }
    
    # Smart open - opens HTML if available, falls back to markdown
    smart_open_report() {
      local session_path="$1"
      
      if [ -f "$session_path/report.html" ]; then
        auto_open_report "$session_path" "html"
      elif [ -f "$session_path/report.md" ]; then
        auto_open_report "$session_path" "markdown"
      elif [ -f "$session_path/report.json" ]; then
        auto_open_report "$session_path" "json"
      else
        warn "No report files found in $session_path"
        return 1
      fi
    }
  '';
}
