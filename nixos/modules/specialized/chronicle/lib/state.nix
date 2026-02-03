{ lib, pkgs }:

rec {
  # State directory setup
  stateDir = ''
    STATE_DIR="''${XDG_RUNTIME_DIR:-/tmp}/chronicle-$USER"
    STATE_FILE="$STATE_DIR/recording.state"
    PID_FILE="$STATE_DIR/recording.pid"
    mkdir -p "$STATE_DIR"
  '';

  # Load state from file
  loadState = ''
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
      return 0
    }
  '';

  # Save state to file
  saveState = ''
    save_state() {
      cat > "$STATE_FILE" << EOF
RECORDING=$RECORDING
STEP_COUNT=$STEP_COUNT
SESSION_ID="$SESSION_ID"
CURRENT_WINDOW="$CURRENT_WINDOW"
EOF
      echo $$ > "$PID_FILE"
    }
  '';

  # Remove state file
  removeState = ''
    remove_state() {
      rm -f "$STATE_FILE" "$PID_FILE"
    }
  '';

  # Get current state
  getCurrentState = ''
    get_current_state() {
      load_state || return 1
      
      if [ "$RECORDING" = "true" ]; then
        echo "recording"
      else
        echo "idle"
      fi
    }
  '';

  # Initialize state variables
  initState = ''
    # State variables (will be loaded from state file if exists)
    RECORDING=false
    STEP_COUNT=0
    SESSION_ID=""
    CURRENT_WINDOW=""
    DEBUG_MODE=false
  '';
}
