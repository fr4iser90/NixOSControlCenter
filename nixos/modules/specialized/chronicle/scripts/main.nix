{ lib, pkgs, cfg, chronicleLib, backend, getModuleApi }:

let
  ui = getModuleApi "cli-formatter";

  # Import handlers
  recordingHandler = import ../handlers/recording.nix { 
    inherit lib pkgs cfg chronicleLib; 
  };
  exportHandler = import ../handlers/export.nix {
    inherit lib pkgs cfg;
  };
  
  # Import backends
  x11Backend = import ../backends/x11/screenshot.nix { 
    inherit lib pkgs cfg;
  };
  waylandBackend = import ../backends/wayland/screenshot.nix {
    inherit lib pkgs cfg;
  };
  
  # Extract library functions
  utils = chronicleLib.utils;
  privacy = chronicleLib.privacy;
  state = chronicleLib.state;
  validators = chronicleLib.validators;

in pkgs.writeShellScriptBin "chronicle" ''
  #!/usr/bin/env bash
  set -euo pipefail

  # Configuration
  OUTPUT_DIR="${cfg.outputDir}"
  eval OUTPUT_DIR="$OUTPUT_DIR"
  MAX_STEPS=${toString (cfg.recording.maxSteps or 1000)}
  SCREENSHOT_QUALITY=${toString (cfg.recording.screenshotQuality or 85)}
  backend="${backend}"

  # State setup
  ${state.stateDir}
  ${state.initState}

  # Utility functions (cli-formatter)
  ${utils.shellHelpers}

  # Privacy functions
  ${privacy.isWindowAllowed { 
    whitelist = cfg.privacy.whitelist or [];
    blacklist = cfg.privacy.blacklist or [ "password-manager" "keepassxc" "1password" "bitwarden" ];
  }}
  
  ${privacy.redactSensitiveText {
    patterns = cfg.privacy.sensitivePatterns or [];
    enabled = cfg.privacy.redactPasswords or true;
  }}
  
  ${privacy.generateStepDescription {
    redactPasswords = cfg.privacy.redactPasswords or true;
    sensitivePatterns = cfg.privacy.sensitivePatterns or [];
  }}

  # State management
  ${state.loadState}
  ${state.saveState}
  ${state.removeState}

  # Backend functions
  ${if backend == "x11" then ''
    ${x11Backend.takeScreenshot {
      stepNum = "$STEP_COUNT";
      timestamp = "$timestamp";
      outputDir = "$OUTPUT_DIR";
      sessionId = "$SESSION_ID";
      quality = cfg.recording.screenshotQuality or 85;
    }}
    ${x11Backend.getWindowInfo}
    ${x11Backend.monitorWindowChanges}
  '' else ''
    ${waylandBackend.takeScreenshot {
      stepNum = "$STEP_COUNT";
      timestamp = "$timestamp";
      outputDir = "$OUTPUT_DIR";
      sessionId = "$SESSION_ID";
      quality = cfg.recording.screenshotQuality or 85;
    }}
    ${waylandBackend.getWindowInfo}
    ${waylandBackend.manualCaptureMode}
  ''}

  # Recording handlers
  ${recordingHandler.recordStep}
  ${recordingHandler.startRecording}
  ${recordingHandler.stopRecording}
  ${recordingHandler.captureManualStep}

  # Export handler
  ${exportHandler.exportRecording}

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
      ncc_cli_header "Chronicle"
      # Check for flags
      DAEMON_MODE=false
      DEBUG_MODE=false
      for arg in "''${@:2}"; do
        case "$arg" in
          "--daemon"|"-d")
            DAEMON_MODE=true
            ;;
          "--debug"|"-v"|"--verbose")
            DEBUG_MODE=true
            export NCC_VERBOSE=1
            ;;
        esac
      done

      ${ui.messages.loading "Starting recording…"}
      if [ "$DAEMON_MODE" = "true" ]; then
        # Fork to background
        if [ "$DEBUG_MODE" = "true" ]; then
          nohup "$0" start-foreground --debug 2>&1 | tee -a "/tmp/chronicle-debug.log" &
        else
          nohup "$0" start-foreground > /dev/null 2>&1 &
        fi
        disown
        sleep 0.5
        load_state || true
        if [ "$RECORDING" = "true" ]; then
          log "Recording started in background (PID: $(cat "$PID_FILE" 2>/dev/null || echo 'unknown'))"
          ${ui.messages.info "Session: $SESSION_ID"}
          ncc_cli_next "ncc chronicle status"
          if [ "$DEBUG_MODE" = "true" ]; then
            debug "Debug log: /tmp/chronicle-debug.log"
          fi
        else
          error "Failed to start recording in background"
          ncc_cli_next "ncc chronicle test"
          exit 1
        fi
      else
        start_recording
        ncc_cli_next "ncc chronicle stop"
      fi
      ;;
      
    "start-foreground")
      if [ "''${2-}" = "--debug" ] || [ "''${2-}" = "-v" ]; then
        DEBUG_MODE=true
        export NCC_VERBOSE=1
      fi
      start_recording
      ;;
      
    "stop")
      ncc_cli_header "Chronicle"
      ${ui.messages.loading "Stopping recording…"}
      stop_recording
      ncc_cli_next "ncc chronicle list"
      ;;
      
    "capture")
      ncc_cli_header "Chronicle"
      capture_manual_step
      ncc_cli_next "ncc chronicle stop"
      ;;
      
    "status")
      ncc_cli_header "Chronicle"
      load_state || true
      if [ "$RECORDING" = "true" ]; then
        ${ui.messages.success "Recording active: $SESSION_ID (Step $STEP_COUNT)"}
        ${ui.messages.info "State file: $STATE_FILE"}
        ${ui.messages.info "Output directory: $OUTPUT_DIR/$SESSION_ID"}
        ncc_cli_next "ncc chronicle stop"
      else
        ${ui.messages.warning "No active recording"}
        ncc_cli_next "ncc chronicle start"
      fi
      ;;
      
    "list")
      ncc_cli_header "Chronicle"
      ${ui.messages.info "Available recordings in $OUTPUT_DIR:"}
      if [ ! -d "$OUTPUT_DIR" ]; then
        warn "Output directory does not exist: $OUTPUT_DIR"
        ncc_cli_next "ncc chronicle start"
        exit 1
      fi
      find "$OUTPUT_DIR" -maxdepth 1 -type d -name "session_*" 2>/dev/null | sort -r | while read session_path; do
        session=$(basename "$session_path")
        if [ -f "$session_path/session.json" ]; then
          start_time=$(${pkgs.jq}/bin/jq -r '.start_time' "$session_path/session.json")
          total_steps=$(${pkgs.jq}/bin/jq -r '.total_steps // "in progress"' "$session_path/session.json")
          ${ui.messages.info "$session — Started: $start_time | Steps: $total_steps"}
        fi
      done
      ncc_cli_next "ncc chronicle cleanup"
      ;;
      
    "cleanup")
      ncc_cli_header "Chronicle"
      if [ ! -d "$OUTPUT_DIR" ]; then
        warn "Output directory does not exist: $OUTPUT_DIR"
        exit 1
      fi
      ${ui.messages.loading "Cleaning recordings older than 30 days…"}
      count=$(find "$OUTPUT_DIR" -type d -name "session_*" -mtime +30 2>/dev/null | wc -l)
      if [ "$count" -eq 0 ]; then
        log "No recordings older than 30 days found"
      else
        find "$OUTPUT_DIR" -type d -name "session_*" -mtime +30 -exec rm -rf {} \; 2>/dev/null || true
        log "Cleaned up $count recording(s) older than 30 days"
      fi
      if [ -f "$STATE_FILE" ]; then
        load_state || {
          log "Cleaned up stale state file"
        }
      fi
      ncc_cli_next "ncc chronicle list"
      ;;
      
    "test")
      ncc_cli_header "Chronicle"
      ${ui.messages.loading "Running Step Recorder System Tests…"}
      # Simplified test - just check if tools are available
      missing_tools=""
      for tool in bash date jq mkdir cat; do
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
      fi
      
      if [ -n "$missing_tools" ]; then
        error "Missing required tools:$missing_tools"
        ncc_cli_next "install missing tools, then: ncc chronicle test"
        exit 1
      else
        log "All required tools are available"
        log "Step Recorder is ready to use"
        ncc_cli_next "ncc chronicle start"
      fi
      ;;
      
    "gui")
      if command -v chronicle-gui >/dev/null 2>&1; then
        exec chronicle-gui
      else
        error "chronicle-gui not installed (enable modules.specialized.chronicle.gui.enableQt)"
        ncc_cli_next "enable chronicle GUI in systemConfig, then rebuild"
        exit 1
      fi
      ;;

    "help"|*)
      cat << EOF
Chronicle — workflow step recorder

Usage: ncc chronicle <command> [options]

Commands:
  start [options]   Start a new recording session
                      --daemon / -d   Run in background
                      --debug / -v    Verbose debug output
  stop              Stop the current recording session
  capture           Capture a manual step (Wayland-compatible)
  status            Show current recording status
  list              List all available recordings
  cleanup           Clean up recordings older than 30 days
  test              Run system tests
  gui               Open PySide6 control window
  help              Show this help message

Configuration:
  Backend:  $backend
  Mode:     ${cfg.mode}
  Output:   $OUTPUT_DIR
  Format:   ${cfg.format}

Examples:
  ncc chronicle start
  ncc chronicle start --daemon
  ncc chronicle status
  ncc chronicle stop
  ncc chronicle capture
  ncc chronicle gui
EOF
      ;;
  esac
''
