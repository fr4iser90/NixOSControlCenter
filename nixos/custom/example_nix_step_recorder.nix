{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # Module configuration with sensible defaults
  cfg = config.stepRecorder or {
    enable = true;
    mode = "automatic";  # "automatic" (X11) | "manual" (Wayland)
    outputDir = "$HOME/.local/share/step-records";
    format = "html";     # "html" | "markdown" | "json"
    privacy = {
      redactPasswords = true;
      whitelist = [ ];  # Empty = record all windows (recommended for most users)
                        # Add apps to restrict: [ "firefox" "chromium" "code" ]
      blacklist = [ "password-manager" "keepassxc" "1password" "bitwarden" ];
      enableOCR = false;
      sensitivePatterns = [
        "password.*[:=].*"
        "secret.*[:=].*"
        "token.*[:=].*"
        "api[_-]?key.*[:=].*"
        "private[_-]?key.*[:=].*"
      ];
    };
    recording = {
      screenshotQuality = 85;
      maxSteps = 1000;
      autoTrigger = true;
      manualTrigger = true;
    };
  };

  # Helper functions
  optionalString = lib.optionalString;
  optional = lib.optional;

  # Determine backend based on session type and mode
  backend = if cfg.mode == "automatic" then "x11" else "wayland";

  # Packages needed for recording
  recorderPackages = with pkgs; [
    # Core tools
    bash
    coreutils
    findutils
    jq
    zip
    unzip

    # X11 backend tools
    xorg.xinput
    xorg.xprop
    xdotool
    maim
    imagemagick
    xev  # For event capture

    # Wayland backend tools
    grim
    slurp
    wtype
    kdePackages.spectacle
    libinput  # For event capture on Wayland

    # GUI dependencies
    python3
    python3Packages.pygobject3
    python3Packages.pydbus
    gtk4
    libadwaita
    gobject-introspection
    graphene
    pango
    cairo
    gdk-pixbuf
    harfbuzz

    # System tray
    yad

    # Optional: OCR support
  ] ++ optional cfg.privacy.enableOCR (with pkgs; [ tesseract tesseract-eng ]);

  # Generate recording script
  recorderScript = pkgs.writeShellScriptBin "step-recorder" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Configuration
    OUTPUT_DIR="${cfg.outputDir}"
    # Expand $HOME and other variables in OUTPUT_DIR
    eval OUTPUT_DIR="$OUTPUT_DIR"
    MAX_STEPS=${toString cfg.recording.maxSteps}
    SCREENSHOT_QUALITY=${toString cfg.recording.screenshotQuality}
    backend="${backend}"

    # State file location (use XDG_RUNTIME_DIR if available, otherwise /tmp)
    STATE_DIR="''${XDG_RUNTIME_DIR:-/tmp}/step-recorder-$USER"
    STATE_FILE="$STATE_DIR/recording.state"
    PID_FILE="$STATE_DIR/recording.pid"

    # Create state directory
    mkdir -p "$STATE_DIR"

    # State variables (will be loaded from state file if exists)
    RECORDING=false
    STEP_COUNT=0
    SESSION_ID=""
    CURRENT_WINDOW=""
    DEBUG_MODE=false

    # Load state from file
    load_state() {
      if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
        # Validate PID still exists
        if [ -f "$PID_FILE" ]; then
          local pid=$(cat "$PID_FILE")
          if ! kill -0 "$pid" 2>/dev/null; then
            # Process is dead, clean up stale state
            warn "Found stale recording state. Cleaning up..."
            rm -f "$STATE_FILE" "$PID_FILE"
            RECORDING=false
            SESSION_ID=""
            STEP_COUNT=0
            return 1
          fi
        fi
      fi
    }

    # Save state to file
    save_state() {
      cat > "$STATE_FILE" << EOF
RECORDING=$RECORDING
STEP_COUNT=$STEP_COUNT
SESSION_ID="$SESSION_ID"
CURRENT_WINDOW="$CURRENT_WINDOW"
EOF
      echo $$ > "$PID_FILE"
    }

    # Remove state file
    remove_state() {
      rm -f "$STATE_FILE" "$PID_FILE"
    }

    log() {
      echo "✅ [StepRecorder] $1"
    }

    warn() {
      echo "⚠️  [StepRecorder] $1"
    }

    error() {
      echo "❌ [StepRecorder] $1" >&2
    }

    # Debug logging
    debug() {
      if [ "$DEBUG_MODE" = "true" ]; then
        echo "🐛 [DEBUG] $1" >&2
      fi
    }

    # Privacy functions
    is_window_allowed() {
      local window_title="$1"
      local app_name="$2"

      debug "Checking window: title='$window_title' app='$app_name'"

      # Check blacklist first
      for blocked in ${lib.concatStringsSep " " cfg.privacy.blacklist}; do
        # Case-insensitive matching
        if [[ "''${window_title,,}" == *"''${blocked,,}"* ]] || [[ "''${app_name,,}" == *"''${blocked,,}"* ]]; then
          debug "BLOCKED by blacklist: $blocked"
          return 1
        fi
      done

      # Check whitelist (if not empty)
      if [ ${toString (lib.length cfg.privacy.whitelist)} -gt 0 ]; then
        local allowed=false
        for allowed_app in ${lib.concatStringsSep " " cfg.privacy.whitelist}; do
          # Case-insensitive matching
          if [[ "''${window_title,,}" == *"''${allowed_app,,}"* ]] || [[ "''${app_name,,}" == *"''${allowed_app,,}"* ]]; then
            allowed=true
            debug "ALLOWED by whitelist: $allowed_app"
            break
          fi
        done
        if [ "$allowed" != "true" ]; then
          debug "NOT in whitelist, rejecting"
          return 1
        fi
      else
        debug "No whitelist configured, allowing all"
      fi

      debug "Window ALLOWED"
      return 0
    }

    redact_sensitive_text() {
      local text="$1"
      local redacted="$text"

      if [ "${if cfg.privacy.redactPasswords then "true" else "false"}" = "true" ]; then
        # Redact common sensitive patterns
        redacted=$(echo "$redacted" | sed -E 's/(password|secret|token|key)[[:space:]]*[:=][[:space:]]*[^[:space:]]+/***REDACTED***/gi')
        redacted=$(echo "$redacted" | sed -E 's/[0-9]{4}[- ][0-9]{4}[- ][0-9]{4}[- ][0-9]{4}/****-****-****-****/g')
      fi

      echo "$redacted"
    }

    # Get current window info
    get_window_info() {
      if [ "$backend" = "x11" ]; then
        local window_id=$(xprop -root _NET_ACTIVE_WINDOW | awk '{print $5}')
        if [ "$window_id" != "0x0" ]; then
          local window_title=$(xprop -id "$window_id" _NET_WM_NAME | sed -e 's/_NET_WM_NAME(UTF8_STRING) = //' -e 's/"//g')
          local app_name=$(xprop -id "$window_id" WM_CLASS | awk -F'"' '{print $2}')
          echo "$window_title|$app_name"
        else
          echo "Desktop|$DESKTOP_SESSION"
        fi
      else
        # Wayland fallback
        echo "Unknown|$WAYLAND_DISPLAY"
      fi
    }

    # Take screenshot
    take_screenshot() {
      local step_num="$1"
      local timestamp="$2"
      # Create step directory first
      local step_dir="$OUTPUT_DIR/$SESSION_ID/steps"
      mkdir -p "$step_dir"
      # Save screenshot in steps/ directory
      local output_file="$step_dir/step_"
      output_file="''${output_file}''${step_num}_"
      output_file="''${output_file}''${timestamp}.png"

      debug "Taking screenshot: $output_file"

      # Auto-detect session type
      local session_type="''${XDG_SESSION_TYPE:-x11}"
      debug "Detected session type: $session_type"

      local error_msg

      if [ "$session_type" = "wayland" ]; then
        # Wayland: try spectacle first (KDE), then grim
        if command -v spectacle &> /dev/null; then
          debug "Using spectacle for Wayland screenshot"
          if error_msg=$(spectacle -b -n -o "$output_file" 2>&1); then
            debug "Screenshot saved successfully with spectacle"
          else
            error "Screenshot failed: $error_msg"
            warn "Step will be recorded without screenshot"
            echo ""
            return 1
          fi
        elif command -v grim &> /dev/null; then
          debug "Using grim for Wayland screenshot"
          if error_msg=$(grim "$output_file" 2>&1); then
            debug "Screenshot saved successfully with grim"
          else
            error "Screenshot failed: $error_msg"
            warn "Step will be recorded without screenshot"
            echo ""
            return 1
          fi
        else
          error "No Wayland screenshot tool available (spectacle or grim)"
          warn "Step will be recorded without screenshot"
          echo ""
          return 1
        fi
      else
        # X11: use maim
        debug "Using maim for X11 screenshot"
        if error_msg=$(maim "$output_file" 2>&1); then
          debug "Screenshot saved successfully with maim"
          # Apply quality setting with convert if screenshot quality is not 100
          if [ "$SCREENSHOT_QUALITY" != "100" ]; then
            convert "$output_file" -quality $SCREENSHOT_QUALITY "$output_file" 2>/dev/null || true
          fi
        else
          error "Screenshot failed: $error_msg"
          warn "Step will be recorded without screenshot"
          echo ""
          return 1
        fi
      fi

      # Verify file was created
      if [ ! -f "$output_file" ]; then
        error "Screenshot file not created: $output_file"
        echo ""
        return 1
      fi

      echo "$output_file"
    }

    # Generate step description
    generate_step_description() {
      local action="$1"
      local window_info="$2"
      local timestamp="$3"

      local window_title=$(echo "$window_info" | cut -d'|' -f1)
      local app_name=$(echo "$window_info" | cut -d'|' -f2)

      # Redact sensitive information
      window_title=$(redact_sensitive_text "$window_title")

      case "$action" in
        "click")
          echo "Clicked on '$window_title' ($app_name)"
          ;;
        "keypress")
          echo "Pressed keys in '$window_title' ($app_name)"
          ;;
        "window_change")
          echo "Switched to '$window_title' ($app_name)"
          ;;
        "manual")
          echo "Manual step captured at '$window_title' ($app_name)"
          ;;
        *)
          echo "Action performed in '$window_title' ($app_name)"
          ;;
      esac
    }

    # Record a step
    record_step() {
      local action="$1"
      local window_info="$2"
      local timestamp=$(date '+%Y%m%d_%H%M%S')

      if [ $STEP_COUNT -ge $MAX_STEPS ]; then
        warn "Maximum steps reached ($MAX_STEPS). Stopping recording."
        stop_recording
        return 1
      fi

      STEP_COUNT=$((STEP_COUNT + 1))

      # Create step directory
      local step_dir="$OUTPUT_DIR/$SESSION_ID/steps"
      mkdir -p "$step_dir"

      # Take screenshot (may fail, that's okay)
      local screenshot_file=$(take_screenshot $STEP_COUNT $timestamp || echo "")

      # Generate description
      local description=$(generate_step_description "$action" "$window_info" "$timestamp")

      # Adjust metadata based on whether screenshot succeeded
      local screenshot_name="step_''${STEP_COUNT}_''${timestamp}.png"
      if [ -z "$screenshot_file" ]; then
        debug "Recording step without screenshot"
        screenshot_name=""
      fi

      # Create step metadata
      if [ -n "$screenshot_name" ]; then
        cat > "$step_dir/step_''${STEP_COUNT}.json" << EOF
{
  "step": $STEP_COUNT,
  "timestamp": "$timestamp",
  "action": "$action",
  "window_title": "$(echo "$window_info" | cut -d'|' -f1)",
  "app_name": "$(echo "$window_info" | cut -d'|' -f2)",
  "description": "$description",
  "screenshot": "$screenshot_name"
}
EOF
        log "Step $STEP_COUNT: $description"
        log "Screenshot saved: $screenshot_file"
      else
        cat > "$step_dir/step_''${STEP_COUNT}.json" << EOF
{
  "step": $STEP_COUNT,
  "timestamp": "$timestamp",
  "action": "$action",
  "window_title": "$(echo "$window_info" | cut -d'|' -f1)",
  "app_name": "$(echo "$window_info" | cut -d'|' -f2)",
  "description": "$description",
  "screenshot": null
}
EOF
        log "Step $STEP_COUNT: $description (no screenshot)"
      fi
    }

    # Start recording
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

      # If auto-trigger is enabled, keep the process running for monitoring
      if [ "$backend" = "x11" ] && [ "${if cfg.recording.autoTrigger then "true" else "false"}" = "true" ]; then
        log "Auto-monitoring enabled. Press Ctrl+C or run 'step-recorder stop' to end recording."
        # This will block and keep the process alive
        start_x11_monitoring
      else
        log "Manual mode. Use 'step-recorder capture' to record steps."
        log "Use 'step-recorder stop' to finish recording."
      fi
    }

    # Stop recording
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
      jq --arg end_time "$end_time" --arg step_count "$STEP_COUNT" \
         '.end_time = $end_time | .total_steps = ($step_count | tonumber)' \
         "$OUTPUT_DIR/$SESSION_ID/session.json" > "$OUTPUT_DIR/$SESSION_ID/session_temp.json"
      mv "$OUTPUT_DIR/$SESSION_ID/session_temp.json" "$OUTPUT_DIR/$SESSION_ID/session.json"

      log "Recording stopped. Session: $SESSION_ID"
      log "Total steps: $STEP_COUNT"
      log "Session data: $OUTPUT_DIR/$SESSION_ID/session.json"

      # Export based on configured format
      export_recording "$OUTPUT_DIR/$SESSION_ID"
    }

    # Manual step capture (for Wayland)
    capture_manual_step() {
      # Load state
      load_state || true

      if [ "$RECORDING" = "false" ]; then
        warn "No active recording. Starting new session..."
        start_recording
      fi

      local window_info=$(get_window_info)
      record_step "manual" "$window_info"

      # Save updated state
      save_state
    }

    # Export recording
    export_recording() {
      local session_dir="$1"
      local session_id=$(basename "$session_dir")

      case "${cfg.format}" in
        "html")
          export_html "$session_dir"
          ;;
        "markdown")
          export_markdown "$session_dir"
          ;;
        "json")
          export_json "$session_dir"
          ;;
        *)
          warn "Unknown export format: ${cfg.format}"
          ;;
      esac
    }

    export_html() {
      local session_dir="$1"
      local html_file="$session_dir/report.html"

      cat > "$html_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Step Recorder Report</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px; }
        .meta { background: #f8f9fa; padding: 15px; border-radius: 4px; margin-bottom: 20px; }
        .step { margin-bottom: 30px; border: 1px solid #e9ecef; border-radius: 4px; overflow: hidden; }
        .step-header { background: #007bff; color: white; padding: 10px 15px; font-weight: bold; }
        .step-content { padding: 15px; }
        .step-desc { font-size: 16px; margin-bottom: 15px; color: #495057; }
        .screenshot { text-align: center; margin: 15px 0; }
        .screenshot img { max-width: 100%; border: 1px solid #dee2e6; border-radius: 4px; }
        .meta-info { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; }
        .meta-item { background: white; padding: 10px; border-radius: 4px; border-left: 3px solid #007bff; }
        .footer { margin-top: 30px; text-align: center; color: #6c757d; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Problem Steps Recorder Report</h1>
EOF

      # Add session metadata
      local session_json="$session_dir/session.json"
      local start_time=$(jq -r '.start_time' "$session_json")
      local end_time=$(jq -r '.end_time // "Recording in progress"' "$session_json")
      local backend=$(jq -r '.backend' "$session_json")
      local hostname=$(jq -r '.hostname' "$session_json")
      local user=$(jq -r '.user' "$session_json")
      local total_steps=$(jq -r '.total_steps // "Recording in progress"' "$session_json")

      cat >> "$html_file" << EOF
        <div class="meta">
            <div class="meta-info">
                <div class="meta-item"><strong>Session ID:</strong> $session_id</div>
                <div class="meta-item"><strong>Start Time:</strong> $start_time</div>
                <div class="meta-item"><strong>End Time:</strong> $end_time</div>
                <div class="meta-item"><strong>Backend:</strong> $backend</div>
                <div class="meta-item"><strong>Hostname:</strong> $hostname</div>
                <div class="meta-item"><strong>User:</strong> $user</div>
                <div class="meta-item"><strong>Total Steps:</strong> $total_steps</div>
            </div>
        </div>
EOF

      # Add steps
      local steps_dir="$session_dir/steps"
      if [ -d "$steps_dir" ]; then
        for step_file in "$steps_dir"/step_*.json; do
          if [ -f "$step_file" ]; then
            local step_num=$(jq -r '.step' "$step_file")
            local description=$(jq -r '.description' "$step_file")
            local screenshot=$(jq -r '.screenshot' "$step_file")
            local window_title=$(jq -r '.window_title' "$step_file")
            local app_name=$(jq -r '.app_name' "$step_file")

            cat >> "$html_file" << EOF
        <div class="step">
            <div class="step-header">Step $step_num - $window_title ($app_name)</div>
            <div class="step-content">
                <div class="step-desc">$description</div>
                <div class="screenshot">
                    <img src="steps/$screenshot" alt="Step $step_num Screenshot">
                </div>
            </div>
        </div>
EOF
          fi
        done
      fi

      cat >> "$html_file" << 'EOF'
        <div class="footer">
            Generated by NixOS Step Recorder - Privacy-focused problem documentation tool
        </div>
    </div>
</body>
</html>
EOF

      log "HTML report generated: $html_file"

      # Auto-open HTML in browser
      if command -v xdg-open &> /dev/null; then
        xdg-open "$html_file" &>/dev/null &
        log "Opening report in browser..."
      fi
    }

    export_markdown() {
      local session_dir="$1"
      local md_file="$session_dir/report.md"

      # Add session metadata
      local session_json="$session_dir/session.json"
      local start_time=$(jq -r '.start_time' "$session_json")
      local end_time=$(jq -r '.end_time // "Recording in progress"' "$session_json")
      local backend=$(jq -r '.backend' "$session_json")
      local hostname=$(jq -r '.hostname' "$session_json")
      local user=$(jq -r '.user' "$session_json")
      local total_steps=$(jq -r '.total_steps // "Recording in progress"' "$session_json")

      cat > "$md_file" << EOF
# Problem Steps Recorder Report

## Session Information

- **Session ID:** $session_id
- **Start Time:** $start_time
- **End Time:** $end_time
- **Backend:** $backend
- **Hostname:** $hostname
- **User:** $user
- **Total Steps:** $total_steps

## Steps

EOF

      # Add steps
      local steps_dir="$session_dir/steps"
      if [ -d "$steps_dir" ]; then
        for step_file in "$steps_dir"/step_*.json; do
          if [ -f "$step_file" ]; then
            local step_num=$(jq -r '.step' "$step_file")
            local description=$(jq -r '.description' "$step_file")
            local window_title=$(jq -r '.window_title' "$step_file")
            local app_name=$(jq -r '.app_name' "$step_file")
            local screenshot=$(jq -r '.screenshot' "$step_file")

            cat >> "$md_file" << EOF
### Step $step_num: $window_title ($app_name)

**Description:** $description

![Step $step_num Screenshot](steps/$screenshot)

---

EOF
          fi
        done
      fi

      log "Markdown report generated: $md_file"
    }

    export_json() {
      local session_dir="$1"
      local json_file="$session_dir/full_report.json"

      # Combine session and steps data
      local session_json="$session_dir/session.json"
      local steps_dir="$session_dir/steps"

      # Start with session data
      cp "$session_json" "$json_file"

      # Add steps array
      echo ',' >> "$json_file"
      echo '"steps": [' >> "$json_file"

      local first=true
      if [ -d "$steps_dir" ]; then
        for step_file in "$steps_dir"/step_*.json; do
          if [ -f "$step_file" ]; then
            if [ "$first" = "true" ]; then
              first=false
            else
              echo ',' >> "$json_file"
            fi
            cat "$step_file" >> "$json_file"
          fi
        done
      fi

      echo ']' >> "$json_file"
      echo '}' >> "$json_file"

      # Pretty print
      jq '.' "$json_file" > "$json_file.tmp" && mv "$json_file.tmp" "$json_file"

      log "JSON report generated: $json_file"
    }

    # X11 monitoring (automatic mode)
    start_x11_monitoring() {
      # Record initial window
      local initial_window=$(get_window_info)
      local win_title=$(echo "$initial_window" | cut -d'|' -f1)
      local win_app=$(echo "$initial_window" | cut -d'|' -f2)

      debug "Initial window: $initial_window"

      if is_window_allowed "$win_title" "$win_app"; then
        record_step "initial" "$initial_window"
        save_state
      else
        debug "Initial window not allowed by privacy settings"
      fi

      CURRENT_WINDOW="$initial_window"

      while [ "$RECORDING" = "true" ]; do
        # Monitor for window changes
        local current_window=$(get_window_info)

        if [ "$current_window" != "$CURRENT_WINDOW" ]; then
          debug "Window changed from '$CURRENT_WINDOW' to '$current_window'"

          win_title=$(echo "$current_window" | cut -d'|' -f1)
          win_app=$(echo "$current_window" | cut -d'|' -f2)

          if is_window_allowed "$win_title" "$win_app"; then
            record_step "window_change" "$current_window"
            # Update state after recording
            save_state
          else
            debug "Window change not recorded (privacy filtered)"
          fi

          CURRENT_WINDOW="$current_window"
        fi
        sleep 0.5
      done
    }

    # Signal handlers
    cleanup_on_exit() {
      if [ "$RECORDING" = "true" ]; then
        log "Interrupt received. Stopping recording..."
        stop_recording
      fi
      exit 0
    }

    trap cleanup_on_exit SIGTERM SIGINT

    # Main command handling
    case "''${1-help}" in
      "start")
        # Check for flags
        DAEMON_MODE=false
        for arg in "''${@:2}"; do
          case "$arg" in
            "--daemon"|"-d")
              DAEMON_MODE=true
              ;;
            "--debug")
              DEBUG_MODE=true
              ;;
          esac
        done

        if [ "$DAEMON_MODE" = "true" ]; then
          # Fork to background
          if [ "$DEBUG_MODE" = "true" ]; then
            nohup "$0" start-foreground --debug 2>&1 | tee -a "/tmp/step-recorder-debug.log" &
          else
            nohup "$0" start-foreground > /dev/null 2>&1 &
          fi
          disown
          sleep 0.5  # Give it time to start
          load_state || true
          if [ "$RECORDING" = "true" ]; then
            log "Recording started in background (PID: $(cat "$PID_FILE" 2>/dev/null || echo 'unknown'))"
            log "Session: $SESSION_ID"
            log "Use 'step-recorder status' to check progress"
            log "Use 'step-recorder stop' to end recording"
            if [ "$DEBUG_MODE" = "true" ]; then
              log "Debug output: tail -f /tmp/step-recorder-debug.log"
            fi
          else
            error "Failed to start recording in background"
            exit 1
          fi
        else
          start_recording
        fi
        ;;
      "start-foreground")
        # Internal command for daemon mode
        # Check for debug flag
        if [ "''${2-}" = "--debug" ]; then
          DEBUG_MODE=true
        fi
        start_recording
        ;;
      "start-foreground")
        # Internal command for daemon mode
        start_recording
        ;;
      "stop")
        stop_recording
        ;;
      "capture")
        capture_manual_step
        ;;
      "status")
        load_state || true
        if [ "$RECORDING" = "true" ]; then
          echo "✅ Recording active: $SESSION_ID (Step $STEP_COUNT)"
          echo "   State file: $STATE_FILE"
          echo "   Output directory: $OUTPUT_DIR/$SESSION_ID"
        else
          echo "⚠️  No active recording"
        fi
        ;;
      "list")
        echo "📁 Available recordings in $OUTPUT_DIR:"
        if [ ! -d "$OUTPUT_DIR" ]; then
          warn "Output directory does not exist: $OUTPUT_DIR"
          exit 1
        fi
        find "$OUTPUT_DIR" -maxdepth 1 -type d -name "session_*" 2>/dev/null | sort -r | while read session_path; do
          session=$(basename "$session_path")
          if [ -f "$session_path/session.json" ]; then
            start_time=$(jq -r '.start_time' "$session_path/session.json")
            total_steps=$(jq -r '.total_steps // "in progress"' "$session_path/session.json")
            echo "  📊 $session"
            echo "     Started: $start_time | Steps: $total_steps"
          fi
        done
        ;;
      "cleanup")
        if [ ! -d "$OUTPUT_DIR" ]; then
          warn "Output directory does not exist: $OUTPUT_DIR"
          exit 1
        fi
        count=$(find "$OUTPUT_DIR" -type d -name "session_*" -mtime +30 | wc -l)
        if [ "$count" -eq 0 ]; then
          log "No recordings older than 30 days found"
        else
          find "$OUTPUT_DIR" -type d -name "session_*" -mtime +30 -exec rm -rf {} \;
          log "Cleaned up $count recording(s) older than 30 days"
        fi
        # Also clean up stale state files
        if [ -f "$STATE_FILE" ]; then
          load_state || {
            log "Cleaned up stale state file"
          }
        fi
        ;;
      "test")
        echo "🧪 Running Step Recorder System Tests..."
        echo ""
        test_failed=false

        # Test 1: Check required tools
        echo "📋 Test 1: Checking required tools..."
        missing_tools=""
        for tool in bash date jq mkdir cat echo; do
          if ! command -v $tool &> /dev/null; then
            missing_tools="$missing_tools $tool"
          fi
        done

        if [ "$backend" = "x11" ]; then
          for tool in xprop maim; do
            if ! command -v $tool &> /dev/null; then
              missing_tools="$missing_tools $tool"
            fi
          done
        else
          for tool in grim; do
            if ! command -v $tool &> /dev/null; then
              missing_tools="$missing_tools $tool"
            fi
          done
        fi

        if [ -n "$missing_tools" ]; then
          error "Missing required tools:$missing_tools"
          test_failed=true
        else
          log "All required tools are available"
        fi

        # Test 2: Check output directory
        echo ""
        echo "📁 Test 2: Checking output directory..."
        eval expanded_dir="$OUTPUT_DIR"
        if mkdir -p "$expanded_dir" 2>/dev/null; then
          if [ -w "$expanded_dir" ]; then
            log "Output directory is writable: $expanded_dir"
          else
            error "Output directory is not writable: $expanded_dir"
            test_failed=true
          fi
        else
          error "Cannot create output directory: $expanded_dir"
          test_failed=true
        fi

        # Test 3: Check state directory
        echo ""
        echo "🗂️  Test 3: Checking state directory..."
        if mkdir -p "$STATE_DIR" 2>/dev/null; then
          if [ -w "$STATE_DIR" ]; then
            log "State directory is writable: $STATE_DIR"
            # Try creating a test state file
            if echo "TEST=true" > "$STATE_DIR/test.state" 2>/dev/null; then
              rm -f "$STATE_DIR/test.state"
              log "State file creation works"
            else
              error "Cannot create state files"
              test_failed=true
            fi
          else
            error "State directory is not writable: $STATE_DIR"
            test_failed=true
          fi
        else
          error "Cannot create state directory: $STATE_DIR"
          test_failed=true
        fi

        # Test 4: Check backend functionality
        echo ""
        echo "🖥️  Test 4: Checking backend ($backend)..."
        if [ "$backend" = "x11" ]; then
          if xprop -root _NET_ACTIVE_WINDOW &> /dev/null; then
            log "X11 backend is functional"
          else
            error "X11 backend not working (are you in an X11 session?)"
            test_failed=true
          fi
        else
          if command -v grim &> /dev/null; then
            log "Wayland tools are available"
          else
            error "Wayland tools not found"
            test_failed=true
          fi
        fi

        # Test 5: Test JSON generation
        echo ""
        echo "📝 Test 5: Testing JSON generation..."
        test_json='{"test": true, "value": 123}'
        if echo "$test_json" | jq '.' &> /dev/null; then
          log "JSON processing works"
        else
          error "JSON processing failed"
          test_failed=true
        fi

        # Test 6: Test screenshot capability (non-destructive)
        echo ""
        echo "📸 Test 6: Testing screenshot capability..."
        test_screenshot_dir="$STATE_DIR/test_screenshots"
        mkdir -p "$test_screenshot_dir"
        test_screenshot="$test_screenshot_dir/test.png"

        if [ "$backend" = "x11" ]; then
          # Check if maim command exists
          if ! command -v maim &> /dev/null; then
            warn "maim command not found"
            warn "Screenshots will not work. Install maim package."
            echo "   Install with: nix-shell -p maim"
          else
            # Try to take a screenshot
            screenshot_error=$(maim "$test_screenshot" 2>&1)
            if [ -f "$test_screenshot" ]; then
              log "Screenshot capability works"
              rm -rf "$test_screenshot_dir"
            else
              warn "Screenshot test failed: $screenshot_error"
              warn "This may be due to display permissions or configuration."
              warn "Try running manually: maim test.png"
            fi
          fi
        else
          log "Wayland screenshot test skipped (would require user interaction)"
        fi

        # Test 7: Test privacy functions
        echo ""
        echo "🔒 Test 7: Testing privacy functions..."
        test_text="password=secret123"
        redacted=$(redact_sensitive_text "$test_text")
        if [[ "$redacted" == *"REDACTED"* ]]; then
          log "Privacy redaction works"
        else
          warn "Privacy redaction may not be working correctly"
        fi

        # Test 8: Check configuration
        echo ""
        echo "⚙️  Test 8: Checking configuration..."
        echo "   Backend: $backend"
        echo "   Mode: ${cfg.mode}"
        echo "   Max Steps: $MAX_STEPS"
        echo "   Screenshot Quality: $SCREENSHOT_QUALITY"
        echo "   Output Format: ${cfg.format}"
        log "Configuration loaded successfully"

        # Summary
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        if [ "$test_failed" = "true" ]; then
          error "CRITICAL tests FAILED. Please fix the issues above."
          echo ""
          echo "Common fixes:"
          echo "  - Missing tools: Rebuild NixOS after ensuring packages are in config"
          echo "  - Permission issues: Check directory permissions"
          echo "  - Backend issues: Verify you're in correct display server session"
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          exit 1
        else
          log "Core tests PASSED! Step Recorder is ready to use."
          echo ""
          echo "  Quick start:"
          echo "    step-recorder start --daemon    # Start recording in background"
          echo "    step-recorder status            # Check recording status"
          echo "    step-recorder stop              # Stop and generate report"
          echo ""
          echo "  Note: Warnings above are non-critical but should be addressed"
          echo "        for full functionality."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          exit 0
        fi
        ;;
      "help"|*)
        cat << EOF
📝 Step Recorder - NixOS Problem Steps Recorder

Usage: step-recorder <command> [options]

Commands:
  start [options]   - Start a new recording session
                      --daemon or -d: Run in background (detached)
                      --debug: Enable debug output
                      Without flags: Run in foreground (blocking)
  stop              - Stop the current recording session
  capture           - Capture a manual step (useful for Wayland)
  status            - Show current recording status
  list              - List all available recordings
  cleanup           - Clean up recordings older than 30 days
  test              - Run system tests to verify everything works
  help              - Show this help message

Configuration:
  Backend:  $backend
  Mode:     ${cfg.mode}
  Output:   $OUTPUT_DIR
  Format:   ${cfg.format}

State Files:
  State:    $STATE_FILE
  PID:      $PID_FILE

Examples:
  # Foreground mode (blocking, shows all activity)
  step-recorder start

  # Background mode (daemon, runs detached)
  step-recorder start --daemon

  # Debug mode (see what's being detected)
  step-recorder start --debug

  # Background with debug logging
  step-recorder start --daemon --debug
  tail -f /tmp/step-recorder-debug.log

  # Check recording status
  step-recorder status

  # Stop and export report
  step-recorder stop

  # Manual capture (for Wayland or manual mode)
  step-recorder capture

  # List all recordings
  step-recorder list

Notes:
  - In X11 automatic mode, foreground mode monitors windows continuously
  - In daemon mode, the process runs in background (use 'stop' to end)
  - In manual mode, use 'capture' to manually record steps
  - Reports are generated in ${cfg.format} format when stopping

For more information, see the NixOS Step Recorder documentation.
EOF
        ;;
    esac
  '';

  # Python GTK4 GUI Application
  guiScript = pkgs.writeShellScriptBin "step-recorder-gui" ''
    #!/usr/bin/env bash
    export GI_TYPELIB_PATH="${pkgs.gtk4}/lib/girepository-1.0:${pkgs.libadwaita}/lib/girepository-1.0:${pkgs.pango.out}/lib/girepository-1.0:${pkgs.cairo}/lib/girepository-1.0:${pkgs.gdk-pixbuf}/lib/girepository-1.0:${pkgs.graphene}/lib/girepository-1.0:${pkgs.harfbuzz}/lib/girepository-1.0:${pkgs.gobject-introspection}/lib/girepository-1.0"
    
    exec ${pkgs.python3.withPackages (ps: with ps; [ pygobject3 pydbus ])}/bin/python3 - << 'PYTHON_EOF'
# !/usr/bin/env python3
import json
import os
import subprocess
import sys

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib, Gio  # noqa: E402


class StepRecorderApp(Adw.Application):
    def __init__(self):
        super().__init__(
            application_id='org.nixos.StepRecorder',
            flags=Gio.ApplicationFlags.FLAGS_NONE)
        self.window = None
        self.status_label = None
        self.step_label = None
        self.start_btn = None
        self.stop_btn = None
        self.is_recording = False

    def do_activate(self):
        if not self.window:
            self.window = Adw.ApplicationWindow(application=self)
            self.window.set_title("NixOS Step Recorder")
            self.window.set_default_size(500, 400)

            # Main container
            main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)

            # Header Bar
            header = Adw.HeaderBar()
            header_title = Adw.WindowTitle()
            header_title.set_title("Step Recorder")
            header_title.set_subtitle("Record problem steps")
            header.set_title_widget(header_title)
            main_box.append(header)

            # Content Box
            content_box = Gtk.Box(
                orientation=Gtk.Orientation.VERTICAL,
                spacing=12)
            content_box.set_margin_top(24)
            content_box.set_margin_bottom(24)
            content_box.set_margin_start(24)
            content_box.set_margin_end(24)

            # Status Card
            status_card = Adw.PreferencesGroup()
            status_card.set_title("Recording Status")

            # Status Row
            self.status_label = Gtk.Label(label="⚫ Not Recording")
            self.status_label.add_css_class("title-1")
            status_box = Gtk.Box(
                orientation=Gtk.Orientation.VERTICAL,
                spacing=6)
            status_box.append(self.status_label)

            # Step counter
            self.step_label = Gtk.Label(label="Steps: 0")
            self.step_label.add_css_class("dim-label")
            status_box.append(self.step_label)

            status_card.add(status_box)
            content_box.append(status_card)

            # Control Buttons
            button_box = Gtk.Box(
                orientation=Gtk.Orientation.HORIZONTAL,
                spacing=12)
            button_box.set_halign(Gtk.Align.CENTER)
            button_box.set_margin_top(12)

            # Start Button
            self.start_btn = Gtk.Button(label="Start Recording")
            self.start_btn.add_css_class("suggested-action")
            self.start_btn.add_css_class("pill")
            self.start_btn.set_size_request(150, 40)
            self.start_btn.connect('clicked', self.on_start_clicked)
            button_box.append(self.start_btn)

            # Stop Button
            self.stop_btn = Gtk.Button(label="Stop Recording")
            self.stop_btn.add_css_class("destructive-action")
            self.stop_btn.add_css_class("pill")
            self.stop_btn.set_size_request(150, 40)
            self.stop_btn.set_sensitive(False)
            self.stop_btn.connect('clicked', self.on_stop_clicked)
            button_box.append(self.stop_btn)

            content_box.append(button_box)

            # Quick actions
            quick_box = Gtk.Box(
                orientation=Gtk.Orientation.HORIZONTAL,
                spacing=6)
            quick_box.set_halign(Gtk.Align.CENTER)
            quick_box.set_margin_top(24)

            capture_btn = Gtk.Button(label="📸 Quick Capture")
            capture_btn.connect('clicked', self.on_capture_clicked)
            quick_box.append(capture_btn)

            view_btn = Gtk.Button(label="📁 View Reports")
            view_btn.connect('clicked', self.on_view_clicked)
            quick_box.append(view_btn)

            content_box.append(quick_box)

            # Session list
            sessions_group = Adw.PreferencesGroup()
            sessions_group.set_title("Recent Sessions")
            sessions_group.set_margin_top(24)

            # Scrollable sessions
            scrolled = Gtk.ScrolledWindow()
            scrolled.set_vexpand(True)
            scrolled.set_min_content_height(150)

            self.sessions_list = Gtk.ListBox()
            self.sessions_list.add_css_class("boxed-list")
            scrolled.set_child(self.sessions_list)

            sessions_group.add(scrolled)
            content_box.append(sessions_group)

            main_box.append(content_box)

            self.window.set_content(main_box)

            # Update status on start
            self.update_status()
            self.load_sessions()

            # Auto-refresh status every 2 seconds
            GLib.timeout_add_seconds(2, self.update_status)

        self.window.present()

    def update_status(self):
        try:
            result = subprocess.run(
                ['step-recorder', 'status'],
                capture_output=True, text=True, timeout=2)
            output = result.stdout

            if "Recording active" in output:
                # Extract step count
                import re
                match = re.search(r'Step (\d+)', output)
                steps = match.group(1) if match else "0"

                self.status_label.set_text("🔴 Recording Active")
                self.step_label.set_text(f"Steps: {steps}")
                self.start_btn.set_sensitive(False)
                self.stop_btn.set_sensitive(True)
                self.is_recording = True
            else:
                self.status_label.set_text("⚫ Not Recording")
                self.step_label.set_text("Steps: 0")
                self.start_btn.set_sensitive(True)
                self.stop_btn.set_sensitive(False)
                self.is_recording = False
        except Exception as e:
            print(f"Status update error: {e}")

        return True  # Continue timeout

    def load_sessions(self):
        # Clear existing sessions
        while True:
            row = self.sessions_list.get_row_at_index(0)
            if row is None:
                break
            self.sessions_list.remove(row)

        try:
            output_dir = os.path.expanduser(
                "~/.local/share/step-records")
            if os.path.exists(output_dir):
                sessions = sorted(
                    [d for d in os.listdir(output_dir)
                     if d.startswith("session_")],
                    reverse=True
                )[:5]  # Show last 5

                for session in sessions:
                    session_path = os.path.join(output_dir, session)
                    json_path = os.path.join(
                        session_path, "session.json")

                    if os.path.exists(json_path):
                        with open(json_path, 'r') as f:
                            data = json.load(f)

                        row = Adw.ActionRow()
                        row.set_title(session)

                        steps = data.get('total_steps', 'in progress')
                        row.set_subtitle(f"Steps: {steps}")

                        # Open button
                        open_btn = Gtk.Button(
                            icon_name="document-open-symbolic")
                        open_btn.set_valign(Gtk.Align.CENTER)
                        open_btn.connect(
                            'clicked',
                            lambda b, s=session_path:
                            self.open_report(s))
                        row.add_suffix(open_btn)

                        self.sessions_list.append(row)
        except Exception as e:
            print(f"Load sessions error: {e}")

    def on_start_clicked(self, button):
        try:
            subprocess.Popen(
                ['step-recorder', 'start', '--daemon'],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL)
            GLib.timeout_add(500, self.update_status)
        except Exception as e:
            self.show_error(f"Failed to start recording: {e}")

    def on_stop_clicked(self, button):
        try:
            subprocess.run(['step-recorder', 'stop'], timeout=5)
            self.update_status()
            self.load_sessions()
        except Exception as e:
            self.show_error(f"Failed to stop recording: {e}")

    def on_capture_clicked(self, button):
        try:
            subprocess.run(['step-recorder', 'capture'], timeout=5)
            self.update_status()
        except Exception as e:
            self.show_error(f"Failed to capture step: {e}")

    def on_view_clicked(self, button):
        try:
            output_dir = os.path.expanduser("~/.local/share/step-records")
            if os.path.exists(output_dir):
                subprocess.Popen(['xdg-open', output_dir])
            else:
                self.show_error("No recordings found")
        except Exception as e:
            self.show_error(f"Failed to open directory: {e}")

    def open_report(self, session_path):
        report_html = os.path.join(session_path, "report.html")
        if os.path.exists(report_html):
            subprocess.Popen(['xdg-open', report_html])

    def show_error(self, message):
        dialog = Adw.MessageDialog.new(self.window)
        dialog.set_heading("Error")
        dialog.set_body(message)
        dialog.add_response("ok", "OK")
        dialog.present()


def main():
    app = StepRecorderApp()
    return app.run(sys.argv)


if __name__ == '__main__':
    sys.exit(main())
PYTHON_EOF
  '';

  # System Tray Script (using YAD)
  trayScript = pkgs.writeShellScriptBin "step-recorder-tray" ''
    #!/usr/bin/env bash

    # Check if yad is available
    if ! command -v yad &> /dev/null; then
      echo "YAD not found. Install with: nix-shell -p yad"
      exit 1
    fi

    # Function to get current status
    get_status() {
      if step-recorder status 2>/dev/null | grep -q "Recording active"; then
        echo "recording"
      else
        echo "idle"
      fi
    }

    # Update icon based on status
    while true; do
      status=$(get_status)

      if [ "$status" = "recording" ]; then
        icon="media-record"
        tooltip="Step Recorder - Recording Active"
      else
        icon="media-playback-pause"
        tooltip="Step Recorder - Idle"
      fi

      yad --notification \
        --image="$icon" \
        --text="$tooltip" \
        --menu="Start Recording!step-recorder start --daemon!media-record|\
Stop Recording!step-recorder stop!media-playback-stop|\
Quick Capture!step-recorder capture!camera-photo|\
Open GUI!step-recorder-gui!preferences-system|\
View Reports!xdg-open ~/.local/share/step-records!folder|\
Quit!killall -9 yad!application-exit" &

      PID=$!
      sleep 5
      kill $PID 2>/dev/null || true
    done
  '';

in
{
  # Enable the module
  config = lib.mkIf cfg.enable {
    # Install packages including the recorder script, GUI, and tray
    environment.systemPackages = recorderPackages ++ [ recorderScript guiScript trayScript ];

    # Note: Directory is created at runtime by the script with mkdir -p
    # since we use $HOME which is only available at runtime

    # User service for recording (not system service!)
    systemd.user.services."step-recorder" = {
      description = "Step Recorder Service";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${recorderScript}/bin/step-recorder start";
        Restart = "on-failure";
        RestartSec = 5;
      };
      wantedBy = [ "default.target" ];
    };

    # CLI commands via command-center integration
    environment.etc."step-recorder/commands" = {
      text = ''
        # Step Recorder Commands
        start: Start recording steps
        stop: Stop recording
        capture: Manual step capture (Wayland)
        status: Show recording status
        list: List recordings
        cleanup: Clean old recordings
      '';
      mode = "0644";
    };
  };
}
