{ lib, pkgs, cfg ? {} }:

{
  # Crash recovery and session integrity management
  crashRecovery = ''
    # Lock file management
    LOCK_FILE="$HOME/.local/share/chronicle.lock"
    
    # Create lock file with PID and session info
    create_lock_file() {
      local session_dir="$1"
      local session_id="$2"
      
      mkdir -p "$(dirname "$LOCK_FILE")"
      
      cat > "$LOCK_FILE" << EOF
{
  "pid": $$,
  "session_id": "$session_id",
  "session_dir": "$session_dir",
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "user": "$(whoami)"
}
EOF
      
      log "Lock file created: $LOCK_FILE"
    }
    
    # Remove lock file
    remove_lock_file() {
      if [ -f "$LOCK_FILE" ]; then
        rm -f "$LOCK_FILE"
        log "Lock file removed"
      fi
    }
    
    # Check for existing lock and handle crashes
    check_for_crash() {
      if [ ! -f "$LOCK_FILE" ]; then
        return 0  # No previous session
      fi
      
      log "Found existing lock file, checking for crash..."
      
      # Read lock file
      local locked_pid=$(${pkgs.jq}/bin/jq -r '.pid' "$LOCK_FILE" 2>/dev/null)
      local locked_session_id=$(${pkgs.jq}/bin/jq -r '.session_id' "$LOCK_FILE" 2>/dev/null)
      local locked_session_dir=$(${pkgs.jq}/bin/jq -r '.session_dir' "$LOCK_FILE" 2>/dev/null)
      local locked_timestamp=$(${pkgs.jq}/bin/jq -r '.timestamp' "$LOCK_FILE" 2>/dev/null)
      
      # Check if process is still running
      if [ -n "$locked_pid" ] && kill -0 "$locked_pid" 2>/dev/null; then
        log_error "Step recorder is already running (PID: $locked_pid)"
        ${pkgs.libnotify}/bin/notify-send "Step Recorder" "Another instance is already running" --urgency=critical
        return 1  # Cannot start
      fi
      
      # Process not running - crashed session detected
      log_warn "Detected crashed session: $locked_session_id (PID: $locked_pid, Time: $locked_timestamp)"
      ${pkgs.libnotify}/bin/notify-send "Step Recorder" "Detected crashed session from $locked_timestamp" --urgency=normal
      
      # Offer recovery
      if offer_recovery "$locked_session_id" "$locked_session_dir"; then
        log "Session recovery completed"
      else
        log "Session recovery skipped"
      fi
      
      # Clean up old lock
      remove_lock_file
      return 0
    }
    
    # Offer to recover crashed session
    offer_recovery() {
      local session_id="$1"
      local session_dir="$2"
      
      if [ ! -d "$session_dir" ]; then
        log_warn "Session directory not found: $session_dir"
        return 1
      fi
      
      # Check if session has recoverable data
      local session_json="$session_dir/session.json"
      if [ ! -f "$session_json" ]; then
        log_warn "No session metadata found, cannot recover"
        return 1
      fi
      
      # Ask user if they want to recover
      local response=""
      if command -v zenity &> /dev/null; then
        response=$(${pkgs.zenity}/bin/zenity --question \
          --title="Step Recorder - Crash Recovery" \
          --text="A previous recording session crashed.\n\nSession: $session_id\nWould you like to recover it?" \
          --ok-label="Recover" \
          --cancel-label="Discard" && echo "yes" || echo "no")
      elif command -v kdialog &> /dev/null; then
        ${pkgs.kdePackages.kdialog}/bin/kdialog --yesno "A previous recording session crashed.\n\nSession: $session_id\nWould you like to recover it?" \
          --title "Step Recorder - Crash Recovery" && response="yes" || response="no"
      else
        # Fallback to command line
        read -p "Recover crashed session $session_id? (y/n): " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] && response="yes" || response="no"
      fi
      
      if [ "$response" = "yes" ]; then
        log "Recovering session: $session_id"
        recover_session "$session_id" "$session_dir"
        return 0
      else
        log "Discarding crashed session: $session_id"
        # Mark session as corrupted
        local corrupted_marker="$session_dir/.corrupted"
        echo "Crashed at: $(date -Iseconds)" > "$corrupted_marker"
        return 1
      fi
    }
    
    # Recover a crashed session
    recover_session() {
      local session_id="$1"
      local session_dir="$2"
      
      log "Attempting to recover session: $session_id"
      
      # Update session metadata
      local session_json="$session_dir/session.json"
      local temp_json=$(mktemp)
      
      ${pkgs.jq}/bin/jq '. + {
        recovered: true,
        recovery_time: "'$(date -Iseconds)'",
        original_crash: .end_time // "unknown"
      }' "$session_json" > "$temp_json"
      mv "$temp_json" "$session_json"
      
      # Count recovered steps
      local steps_count=$(find "$session_dir/steps" -name "step_*.json" 2>/dev/null | wc -l)
      log "Recovered $steps_count steps"
      
      # Update total steps in session
      ${pkgs.jq}/bin/jq --arg count "$steps_count" '.total_steps = ($count | tonumber)' "$session_json" > "$temp_json"
      mv "$temp_json" "$session_json"
      
      # Mark session as ended (since we're recovering)
      ${pkgs.jq}/bin/jq '. + {
        end_time: "'$(date -Iseconds)'",
        status: "recovered"
      }' "$session_json" > "$temp_json"
      mv "$temp_json" "$session_json"
      
      # Generate reports for recovered session
      log "Generating reports for recovered session..."
      export_all "$session_dir" "$session_id"
      
      ${pkgs.libnotify}/bin/notify-send "Step Recorder" "Session recovered: $steps_count steps" --urgency=normal
      
      log "Session recovery complete"
    }
    
    # Validate session integrity
    validate_session() {
      local session_dir="$1"
      local issues=()
      
      # Check session.json
      if [ ! -f "$session_dir/session.json" ]; then
        issues+=("Missing session.json")
      else
        # Validate JSON
        if ! ${pkgs.jq}/bin/jq empty "$session_dir/session.json" 2>/dev/null; then
          issues+=("Corrupted session.json")
        fi
      fi
      
      # Check steps directory
      if [ ! -d "$session_dir/steps" ]; then
        issues+=("Missing steps directory")
      fi
      
      # Check for orphaned screenshots
      if [ -d "$session_dir/steps" ]; then
        local step_count=$(find "$session_dir/steps" -name "step_*.json" | wc -l)
        local screenshot_count=$(find "$session_dir/steps" -name "step_*.png" -o -name "step_*.jpg" | wc -l)
        
        if [ "$screenshot_count" -gt "$step_count" ]; then
          issues+=("Orphaned screenshots detected")
        fi
      fi
      
      # Report issues
      if [ ''${#issues[@]} -gt 0 ]; then
        log_warn "Session validation issues found:"
        for issue in "''${issues[@]}"; do
          log_warn "  - $issue"
        done
        return 1
      fi
      
      log "Session validation passed"
      return 0
    }
    
    # Periodic state checkpoint (call this regularly during recording)
    checkpoint_state() {
      local session_dir="$1"
      local checkpoint_file="$session_dir/.checkpoint"
      
      # Save current state
      cat > "$checkpoint_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "pid": $$,
  "step_count": $(find "$session_dir/steps" -name "step_*.json" 2>/dev/null | wc -l),
  "recording_active": true
}
EOF
      
      # Update lock file timestamp
      if [ -f "$LOCK_FILE" ]; then
        local temp_lock=$(mktemp)
        ${pkgs.jq}/bin/jq '.last_checkpoint = "'$(date -Iseconds)'"' "$LOCK_FILE" > "$temp_lock"
        mv "$temp_lock" "$LOCK_FILE"
      fi
    }
    
    # Cleanup handler for graceful shutdown
    cleanup_on_exit() {
      log "Cleanup handler called"
      remove_lock_file
      
      # Mark session as properly ended if still recording
      if [ -n "$SESSION_DIR" ] && [ -d "$SESSION_DIR" ]; then
        local session_json="$SESSION_DIR/session.json"
        if [ -f "$session_json" ]; then
          local temp_json=$(mktemp)
          ${pkgs.jq}/bin/jq '. + {
            end_time: "'$(date -Iseconds)'",
            status: "completed"
          }' "$session_json" > "$temp_json"
          mv "$temp_json" "$session_json"
        fi
      fi
    }
    
    # Register cleanup handler
    trap cleanup_on_exit EXIT INT TERM
  '';
}
