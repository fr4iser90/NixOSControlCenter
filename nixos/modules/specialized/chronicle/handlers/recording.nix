{ lib, pkgs, cfg, chronicleLib }:

let
  backends = {
    x11 = import ../backends/x11/screenshot.nix { inherit lib pkgs cfg; };
    wayland = import ../backends/wayland/screenshot.nix { inherit lib pkgs cfg; };
  };
  
  utils = chronicleLib.utils;
  privacy = chronicleLib.privacy;
  state = chronicleLib.state;
in
{
  # Record a single step
  recordStep = ''
    record_step() {
      local action="$1"
      local window_info="$2"
      local timestamp=$(date '+%Y%m%d_%H%M%S')

      if [ $STEP_COUNT -ge ${toString (cfg.recording.maxSteps or 1000)} ]; then
        warn "Maximum steps reached (${toString (cfg.recording.maxSteps or 1000)}). Stopping recording."
        stop_recording
        return 1
      fi

      STEP_COUNT=$((STEP_COUNT + 1))

      # Create step directory
      local step_dir="$OUTPUT_DIR/$SESSION_ID/steps"
      mkdir -p "$step_dir"

      # Take screenshot (may fail, that's okay)
      local screenshot_file=""
      if [ "$backend" = "x11" ]; then
        screenshot_file=$(take_screenshot_x11 "$timestamp" || echo "")
      else
        screenshot_file=$(take_screenshot_wayland "$timestamp" || echo "")
      fi

      # Generate description
      local description=$(generate_step_description "$action" "$window_info" "$timestamp")

      # Adjust metadata based on whether screenshot succeeded
      local screenshot_name="step_''${STEP_COUNT}_''${timestamp}.png"
      if [ -z "$screenshot_file" ]; then
        debug "Recording step without screenshot"
        screenshot_name="null"
      fi

      # Create step metadata
      cat > "$step_dir/step_''${STEP_COUNT}.json" << EOF
{
  "step": $STEP_COUNT,
  "timestamp": "$timestamp",
  "action": "$action",
  "window_title": "$(echo "$window_info" | cut -d'|' -f1)",
  "app_name": "$(echo "$window_info" | cut -d'|' -f2)",
  "description": "$description",
  "screenshot": $screenshot_name
}
EOF

      if [ "$screenshot_name" != "null" ]; then
        log "Step $STEP_COUNT: $description"
        log "Screenshot saved: $screenshot_file"
      else
        log "Step $STEP_COUNT: $description (no screenshot)"
      fi
    }
  '';

  # Start recording session
  startRecording = ''
    start_recording() {
      # Load existing state
      load_state || true

      if [ "$RECORDING" = "true" ]; then
        warn "Recording is already active: $SESSION_ID"
        return 1
      fi

      SESSION_ID="session_$(date '+%Y%m%d_%H%M%S')"
      mkdir -p "$OUTPUT_DIR/$SESSION_ID"

      # Create session metadata
      cat > "$OUTPUT_DIR/$SESSION_ID/session.json" << EOF
{
  "session_id": "$SESSION_ID",
  "start_time": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "backend": "$backend",
  "mode": "${cfg.mode}",
  "hostname": "$(hostname)",
  "user": "$(whoami)",
  "nixos_version": "$(nixos-version 2>/dev/null || echo 'unknown')"
}
EOF

      RECORDING=true
      STEP_COUNT=0

      # Save state
      save_state

      log "Starting recording session: $SESSION_ID"
      log "Backend: $backend, Mode: ${cfg.mode}"
      log "Output directory: $OUTPUT_DIR/$SESSION_ID"
      log "State file: $STATE_FILE"

      # Start appropriate monitoring mode
      if [ "$backend" = "x11" ] && [ "${toString (cfg.recording.autoTrigger or true)}" = "true" ]; then
        log "Auto-monitoring enabled. Press Ctrl+C or run 'chronicle stop' to end recording."
        monitor_window_changes_x11
      else
        log "Manual mode. Use 'chronicle capture' to record steps."
        log "Use 'chronicle stop' to finish recording."
        manual_capture_mode_wayland
      fi
    }
  '';

  # Stop recording session
  stopRecording = ''
    stop_recording() {
      # Load state from file
      load_state || {
        warn "No active recording to stop."
        return 1
      }

      if [ "$RECORDING" = "false" ]; then
        warn "No active recording to stop."
        return 1
      fi

      RECORDING=false

      # Remove state file
      remove_state

      # Update session metadata
      local end_time=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
      ${pkgs.jq}/bin/jq --arg end_time "$end_time" --arg step_count "$STEP_COUNT" \
         '.end_time = $end_time | .total_steps = ($step_count | tonumber)' \
         "$OUTPUT_DIR/$SESSION_ID/session.json" > "$OUTPUT_DIR/$SESSION_ID/session_temp.json"
      mv "$OUTPUT_DIR/$SESSION_ID/session_temp.json" "$OUTPUT_DIR/$SESSION_ID/session.json"

      log "Recording stopped. Session: $SESSION_ID"
      log "Total steps: $STEP_COUNT"
      log "Session data: $OUTPUT_DIR/$SESSION_ID/session.json"

      # Export based on configured format
      export_recording "$OUTPUT_DIR/$SESSION_ID"
    }
  '';

  # Manual step capture
  captureManualStep = ''
    capture_manual_step() {
      # Load state
      load_state || true

      if [ "$RECORDING" = "false" ]; then
        warn "No active recording. Starting new session..."
        start_recording
      fi

      local window_info=""
      if [ "$backend" = "x11" ]; then
        window_info=$(get_window_info_x11)
      else
        window_info=$(get_window_info_wayland)
      fi
      
      record_step "manual" "$window_info"

      # Save updated state
      save_state
    }
  '';
}
