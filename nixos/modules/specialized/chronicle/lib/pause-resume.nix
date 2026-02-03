{ lib, pkgs, cfg }:

{
  # Pause/Resume functionality for recordings
  pauseResume = ''
    # Toggle pause/resume state
    toggle_pause_resume() {
      load_state || {
        notify_error "No active recording to pause/resume"
        return 1
      }
      
      if [ "$RECORDING" = "false" ]; then
        notify_error "No active recording to pause/resume"
        return 1
      fi
      
      # Toggle pause state
      if [ "''${PAUSED:-false}" = "false" ]; then
        pause_recording
      else
        resume_recording
      fi
    }
    
    # Pause recording
    pause_recording() {
      PAUSED=true
      PAUSE_START_TIME=$(date +%s)
      PAUSE_COUNT=$((''${PAUSE_COUNT:-0} + 1))
      
      # Update session metadata
      local session_file="$OUTPUT_DIR/$SESSION_ID/session.json"
      if [ -f "$session_file" ]; then
        ${pkgs.jq}/bin/jq --arg paused "true" --arg count "$PAUSE_COUNT" \
          '.paused = ($paused | test("true")) | .pause_count = ($count | tonumber) | .pause_start_time = now' \
          "$session_file" > "$session_file.tmp"
        mv "$session_file.tmp" "$session_file"
      fi
      
      save_state
      log "⏸️  Recording paused (Press F9 or 'chronicle resume' to continue)"
      notify_pause "true"
    }
    
    # Resume recording
    resume_recording() {
      local pause_end_time=$(date +%s)
      local pause_duration=$((pause_end_time - ''${PAUSE_START_TIME:-$pause_end_time}))
      TOTAL_PAUSE_DURATION=$((''${TOTAL_PAUSE_DURATION:-0} + pause_duration))
      
      PAUSED=false
      PAUSE_START_TIME=0
      
      # Update session metadata
      local session_file="$OUTPUT_DIR/$SESSION_ID/session.json"
      if [ -f "$session_file" ]; then
        ${pkgs.jq}/bin/jq --arg paused "false" --arg duration "$TOTAL_PAUSE_DURATION" \
          '.paused = ($paused | test("true")) | .total_pause_duration = ($duration | tonumber) | .pause_start_time = null' \
          "$session_file" > "$session_file.tmp"
        mv "$session_file.tmp" "$session_file"
      fi
      
      save_state
      log "▶️  Recording resumed (Paused for ''${pause_duration}s)"
      notify_pause "false"
    }
    
    # Check if currently paused
    is_paused() {
      if [ "''${PAUSED:-false}" = "true" ]; then
        return 0
      else
        return 1
      fi
    }
  '';
}
