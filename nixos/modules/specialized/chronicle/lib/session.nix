{ lib, pkgs, cfg }:

{
  # Session naming and metadata functions
  sessionManagement = ''
    # Prompt for session name and description
    prompt_session_info() {
      local session_name=""
      local session_description=""
      local problem_title=""
      
      # Try GUI dialog first (if available)
      if command -v zenity &> /dev/null; then
        problem_title=$(${pkgs.zenity}/bin/zenity --entry \
          --title="Step Recorder - New Session" \
          --text="Problem Title/Description:" \
          --entry-text="Bug Report - $(date '+%Y-%m-%d')" 2>/dev/null || echo "")
        
        if [ -n "$problem_title" ]; then
          session_description=$(${pkgs.zenity}/bin/zenity --entry \
            --title="Step Recorder - Session Details" \
            --text="Additional details (optional):" \
            --entry-text="" 2>/dev/null || echo "")
        fi
      elif command -v kdialog &> /dev/null; then
        problem_title=$(${pkgs.kdePackages.kdialog}/bin/kdialog --inputbox \
          "Problem Title/Description:" \
          "Bug Report - $(date '+%Y-%m-%d')" 2>/dev/null || echo "")
          
        if [ -n "$problem_title" ]; then
          session_description=$(${pkgs.kdePackages.kdialog}/bin/kdialog --inputbox \
            "Additional details (optional):" \
            "" 2>/dev/null || echo "")
        fi
      fi
      
      # Fallback to command line prompt
      if [ -z "$problem_title" ]; then
        read -p "Problem Title [Bug Report - $(date '+%Y-%m-%d')]: " problem_title
        problem_title="''${problem_title:-Bug Report - $(date '+%Y-%m-%d')}"
        
        read -p "Additional details (optional): " session_description
      fi
      
      # Create session name from title (sanitize)
      session_name=$(echo "$problem_title" | \
        tr '[:upper:]' '[:lower:]' | \
        sed 's/[^a-z0-9]/-/g' | \
        sed 's/--*/-/g' | \
        sed 's/^-//' | \
        sed 's/-$//' | \
        cut -c1-50)
      
      # Export for use in session creation
      export SESSION_NAME="$session_name"
      export PROBLEM_TITLE="$problem_title"
      export SESSION_DESCRIPTION="$session_description"
    }
    
    # Generate session ID with custom name
    generate_session_id() {
      local base_name="''${SESSION_NAME:-session}"
      local timestamp=$(date '+%Y%m%d_%H%M%S')
      echo "''${base_name}_''${timestamp}"
    }
    
    # Create enhanced session metadata
    create_session_metadata() {
      local session_path="$1"
      local session_id="$2"
      
      cat > "$session_path/session.json" << EOF
{
  "session_id": "$session_id",
  "session_name": "''${SESSION_NAME:-session}",
  "problem_title": "''${PROBLEM_TITLE:-No title provided}",
  "description": "''${SESSION_DESCRIPTION:-}",
  "start_time": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "backend": "$backend",
  "mode": "${cfg.mode}",
  "hostname": "$(hostname)",
  "user": "$(whoami)",
  "nixos_version": "$(nixos-version 2>/dev/null || echo 'unknown')",
  "desktop_environment": "''${XDG_CURRENT_DESKTOP:-unknown}",
  "display_protocol": "''${XDG_SESSION_TYPE:-unknown}",
  "kernel": "$(uname -r)",
  "paused": false,
  "pause_count": 0,
  "total_pause_duration": 0
}
EOF
    }
    
    # Template-based session naming
    apply_session_template() {
      local template="''${1:-bug-{date}}"
      local session_name=""
      
      # Replace template variables
      session_name="$template"
      session_name="${session_name//\{date\}/$(date '+%Y%m%d')}"
      session_name="${session_name//\{time\}/$(date '+%H%M%S')}"
      session_name="${session_name//\{datetime\}/$(date '+%Y%m%d_%H%M%S')}"
      session_name="${session_name//\{user\}/$(whoami)}"
      session_name="${session_name//\{hostname\}/$(hostname)}"
      
      echo "$session_name"
    }
  '';
  
  # Incremental save functionality
  incrementalSave = ''
    # Save step immediately after capture
    save_step_incremental() {
      local step_num="$1"
      local step_dir="$OUTPUT_DIR/$SESSION_ID/steps"
      
      # Ensure step is written to disk immediately
      if [ -f "$step_dir/step_''${step_num}.json" ]; then
        sync "$step_dir/step_''${step_num}.json"
        debug "Step $step_num saved incrementally"
      fi
      
      # Update session file with latest step count
      update_session_step_count "$step_num"
    }
    
    # Update session metadata incrementally
    update_session_step_count() {
      local step_count="$1"
      local session_file="$OUTPUT_DIR/$SESSION_ID/session.json"
      
      if [ -f "$session_file" ]; then
        ${pkgs.jq}/bin/jq --arg count "$step_count" \
          '.current_steps = ($count | tonumber) | .last_update = now | strftime("%Y-%m-%dT%H:%M:%SZ")' \
          "$session_file" > "$session_file.tmp"
        mv "$session_file.tmp" "$session_file"
        sync "$session_file"
      fi
    }
    
    # Periodic auto-save
    auto_save_session() {
      # Save current state every 30 seconds
      while [ "$RECORDING" = "true" ]; do
        sleep 30
        if [ "$RECORDING" = "true" ]; then
          save_state
          update_session_step_count "$STEP_COUNT"
          debug "Auto-saved session state"
        fi
      done
    }
  '';
}
