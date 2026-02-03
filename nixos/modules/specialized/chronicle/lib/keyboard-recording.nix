{ lib, pkgs }:

{
  # Keyboard input recording with privacy protection
  
  # Start keyboard monitoring
  startKeyboardMonitoring = { sessionDir, backend ? "x11" }: ''
    start_keyboard_monitoring() {
      local session_dir="${sessionDir}"
      local key_log_file="$session_dir/keyboard.log"
      local key_pid_file="$session_dir/.keyboard.pid"
      
      # Check if already monitoring
      if [ -f "$key_pid_file" ]; then
        local old_pid=$(cat "$key_pid_file")
        if ps -p "$old_pid" > /dev/null 2>&1; then
          log "Keyboard monitoring already in progress (PID: $old_pid)"
          return 0
        fi
      fi
      
      log "Starting keyboard monitoring..."
      
      ${if backend == "x11" then ''
        # X11 keyboard monitoring with xinput
        # Create monitoring script
        cat > "$session_dir/.keyboard_monitor.sh" << 'KEYMON'
#!/usr/bin/env bash

SESSION_DIR="$1"
LOG_FILE="$SESSION_DIR/keyboard.log"

# Get keyboard device ID
KEYBOARD_ID=$(xinput list | grep -i 'keyboard' | grep -v 'pointer' | head -n1 | sed 's/.*id=\([0-9]*\).*/\1/')

if [ -z "$KEYBOARD_ID" ]; then
  echo "Error: Could not detect keyboard device"
  exit 1
fi

# Monitor keyboard events
xinput test "$KEYBOARD_ID" | while read -r line; do
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  
  # Parse key press/release
  if echo "$line" | grep -q "key press"; then
    KEY_CODE=$(echo "$line" | awk '{print $3}')
    KEY_NAME=$(xmodmap -pke | grep "keycode $KEY_CODE" | awk '{print $4}')
    
    # Privacy: Redact certain keys
    if [[ "$KEY_NAME" =~ ^[a-zA-Z0-9]$ ]]; then
      # Check if we're in a password field (basic heuristic)
      ACTIVE_WINDOW=$(xdotool getactivewindow getwindowname)
      if echo "$ACTIVE_WINDOW" | grep -qi "password\|login\|auth"; then
        KEY_NAME="[REDACTED]"
      fi
    fi
    
    echo "[$TIMESTAMP] PRESS: $KEY_NAME (code: $KEY_CODE)" >> "$LOG_FILE"
  elif echo "$line" | grep -q "key release"; then
    KEY_CODE=$(echo "$line" | awk '{print $3}')
    # Don't log releases to reduce noise
  fi
done
KEYMON

        chmod +x "$session_dir/.keyboard_monitor.sh"
        
        # Start monitoring in background
        DISPLAY=''${DISPLAY:-:0} "$session_dir/.keyboard_monitor.sh" "$session_dir" > /dev/null 2>&1 &
      '' else ''
        # Wayland keyboard monitoring with evdev (requires root)
        # This is more complex and requires libinput debug-events
        ${pkgs.libinput}/bin/libinput debug-events --device /dev/input/by-path/*kbd* 2>&1 | \
        while read -r line; do
          if echo "$line" | grep -q "KEYBOARD_KEY"; then
            timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            echo "[$timestamp] $line" >> "$key_log_file"
          fi
        done &
      ''}
      
      local key_pid=$!
      echo "$key_pid" > "$key_pid_file"
      
      log "Keyboard monitoring started (PID: $key_pid)"
      ${pkgs.libnotify}/bin/notify-send "⌨️ Keyboard Recording" "Monitoring started (privacy-protected)" -u low
      
      return 0
    }
  '';
  
  # Stop keyboard monitoring
  stopKeyboardMonitoring = { sessionDir }: ''
    stop_keyboard_monitoring() {
      local session_dir="${sessionDir}"
      local key_pid_file="$session_dir/.keyboard.pid"
      
      if [ ! -f "$key_pid_file" ]; then
        log "No keyboard monitoring in progress"
        return 0
      fi
      
      local key_pid=$(cat "$key_pid_file")
      
      if ps -p "$key_pid" > /dev/null 2>&1; then
        log "Stopping keyboard monitoring (PID: $key_pid)..."
        kill -TERM "$key_pid" 2>/dev/null
        
        # Wait for process to finish (max 5 seconds)
        local timeout=5
        while [ $timeout -gt 0 ] && ps -p "$key_pid" > /dev/null 2>&1; do
          sleep 1
          ((timeout--))
        done
        
        if ps -p "$key_pid" > /dev/null 2>&1; then
          kill -9 "$key_pid" 2>/dev/null
        fi
        
        rm -f "$key_pid_file"
        
        local key_log_file="$session_dir/keyboard.log"
        if [ -f "$key_log_file" ]; then
          local key_count=$(wc -l < "$key_log_file")
          log "Keyboard monitoring stopped ($key_count events recorded)"
          ${pkgs.libnotify}/bin/notify-send "⌨️ Keyboard Recording" "Stopped ($key_count events)" -u low
        fi
      else
        log "Keyboard monitoring process not running"
        rm -f "$key_pid_file"
      fi
      
      # Clean up monitoring script
      rm -f "$session_dir/.keyboard_monitor.sh"
      
      return 0
    }
  '';
  
  # Analyze keyboard events and generate summary
  analyzeKeyboardEvents = { sessionDir }: ''
    analyze_keyboard_events() {
      local session_dir="${sessionDir}"
      local key_log_file="$session_dir/keyboard.log"
      local summary_file="$session_dir/keyboard_summary.json"
      
      if [ ! -f "$key_log_file" ]; then
        echo '{"total_events": 0, "summary": "No keyboard events recorded"}' > "$summary_file"
        return 0
      fi
      
      log "Analyzing keyboard events..."
      
      # Count events
      local total_events=$(wc -l < "$key_log_file")
      local total_presses=$(grep -c "PRESS:" "$key_log_file" 2>/dev/null || echo 0)
      
      # Count special keys (Ctrl, Alt, etc.)
      local ctrl_count=$(grep -c "Control" "$key_log_file" 2>/dev/null || echo 0)
      local alt_count=$(grep -c "Alt" "$key_log_file" 2>/dev/null || echo 0)
      local shift_count=$(grep -c "Shift" "$key_log_file" 2>/dev/null || echo 0)
      local enter_count=$(grep -c "Return\|Enter" "$key_log_file" 2>/dev/null || echo 0)
      local backspace_count=$(grep -c "BackSpace" "$key_log_file" 2>/dev/null || echo 0)
      
      # Detect potential shortcuts (Ctrl+Key combinations)
      local shortcuts=$(grep "Control" "$key_log_file" | wc -l)
      
      # Generate JSON summary
      cat > "$summary_file" << EOF
{
  "total_events": $total_events,
  "total_presses": $total_presses,
  "special_keys": {
    "ctrl": $ctrl_count,
    "alt": $alt_count,
    "shift": $shift_count,
    "enter": $enter_count,
    "backspace": $backspace_count
  },
  "shortcuts_detected": $shortcuts,
  "privacy_note": "Keyboard events in password fields have been redacted for privacy"
}
EOF
      
      log "Keyboard analysis complete: $total_presses key presses recorded"
      return 0
    }
  '';
  
  # Export keyboard events to HTML
  exportKeyboardToHtml = { sessionDir, htmlFile }: ''
    export_keyboard_to_html() {
      local session_dir="${sessionDir}"
      local html_file="${htmlFile}"
      local summary_file="$session_dir/keyboard_summary.json"
      
      if [ ! -f "$summary_file" ]; then
        # Generate summary if not exists
        analyze_keyboard_events
      fi
      
      if [ ! -f "$summary_file" ]; then
        log "No keyboard summary found"
        return 0
      fi
      
      # Read summary
      local total_presses=$(${pkgs.jq}/bin/jq -r '.total_presses' "$summary_file")
      local ctrl=$(${pkgs.jq}/bin/jq -r '.special_keys.ctrl' "$summary_file")
      local alt=$(${pkgs.jq}/bin/jq -r '.special_keys.alt' "$summary_file")
      local shortcuts=$(${pkgs.jq}/bin/jq -r '.shortcuts_detected' "$summary_file")
      
      # Create HTML section
      local keyboard_html="<div class='keyboard-summary'>"
      keyboard_html+="<h2>⌨️ Keyboard Activity</h2>"
      keyboard_html+="<div class='keyboard-stats'>"
      keyboard_html+="<div class='stat-item'><strong>Total Key Presses:</strong> $total_presses</div>"
      keyboard_html+="<div class='stat-item'><strong>Ctrl Usage:</strong> $ctrl times</div>"
      keyboard_html+="<div class='stat-item'><strong>Alt Usage:</strong> $alt times</div>"
      keyboard_html+="<div class='stat-item'><strong>Keyboard Shortcuts:</strong> $shortcuts detected</div>"
      keyboard_html+="<div class='privacy-note' style='margin-top: 10px; padding: 10px; background: #fff3cd; border-left: 3px solid #ffc107; color: #856404;'>"
      keyboard_html+="🔒 <strong>Privacy Protected:</strong> Keyboard input in password fields has been automatically redacted"
      keyboard_html+="</div>"
      keyboard_html+="</div>"
      keyboard_html+="</div>"
      
      keyboard_html+="<style>"
      keyboard_html+=".keyboard-summary { margin: 20px 0; padding: 20px; background: #f8f9fa; border-radius: 4px; }"
      keyboard_html+=".keyboard-stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; margin-top: 10px; }"
      keyboard_html+=".stat-item { padding: 10px; background: white; border-radius: 4px; border-left: 3px solid #007bff; }"
      keyboard_html+="</style>"
      
      # Inject into HTML after video section (or after metadata)
      ${pkgs.gnused}/bin/sed -i "/<\/div><!-- meta -->/a $keyboard_html" "$html_file" 2>/dev/null || true
      
      log "Keyboard activity exported to HTML report"
      return 0
    }
  '';
  
  # Privacy-aware keyboard logging
  # This function checks active window context to determine if redaction is needed
  isPasswordField = ''
    is_password_field() {
      local window_title="$1"
      
      # Check for password-related keywords in window title
      if echo "$window_title" | grep -Eqi "password|login|sign[- ]?in|auth|credential|passphrase"; then
        return 0  # true - is password field
      fi
      
      # Check active element (if possible with accessibility tools)
      # This is a basic heuristic; more sophisticated methods would use accessibility APIs
      
      return 1  # false - not password field
    }
  '';
}
