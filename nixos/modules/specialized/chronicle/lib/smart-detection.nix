# Smart Step Detection
# Automatically detect and create steps based on user activity patterns
# - Window title changes
# - Click clustering
# - Idle detection
# - Activity-based triggers

{ config, lib, pkgs, ... }:

let
  cfg = config.services.nixos-control-center.chronicle;
  
  # Smart detection configuration
  smartDetectionConfig = {
    # Window title monitoring
    windowTitleChange = cfg.smartDetection.windowTitleChange.enable;
    titleChangeDelay = cfg.smartDetection.windowTitleChange.delaySeconds;
    
    # Click clustering
    clickClustering = cfg.smartDetection.clickClustering.enable;
    clusterRadius = cfg.smartDetection.clickClustering.radiusPixels;
    clusterTimeout = cfg.smartDetection.clickClustering.timeoutSeconds;
    
    # Idle detection
    idleDetection = cfg.smartDetection.idleDetection.enable;
    idleThreshold = cfg.smartDetection.idleDetection.thresholdSeconds;
    
    # Activity triggers
    activityTriggers = cfg.smartDetection.activityTriggers.enable;
    minActivityGap = cfg.smartDetection.activityTriggers.minGapSeconds;
  };

in {
  # Smart detection script
  smartDetectionScript = pkgs.writeShellScriptBin "chronicle-smart-detection" ''
    #!${pkgs.bash}/bin/bash
    # Smart Step Detection Engine
    # Version: 1.2.0
    
    set -euo pipefail
    
    # Configuration
    WINDOW_TITLE_CHANGE="${toString smartDetectionConfig.windowTitleChange}"
    TITLE_CHANGE_DELAY="${toString smartDetectionConfig.titleChangeDelay}"
    CLICK_CLUSTERING="${toString smartDetectionConfig.clickClustering}"
    CLUSTER_RADIUS="${toString smartDetectionConfig.clusterRadius}"
    CLUSTER_TIMEOUT="${toString smartDetectionConfig.clusterTimeout}"
    IDLE_DETECTION="${toString smartDetectionConfig.idleDetection}"
    IDLE_THRESHOLD="${toString smartDetectionConfig.idleThreshold}"
    ACTIVITY_TRIGGERS="${toString smartDetectionConfig.activityTriggers}"
    MIN_ACTIVITY_GAP="${toString smartDetectionConfig.minActivityGap}"
    
    # State directory
    STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/nixos-chronicle"
    DETECTION_STATE="$STATE_DIR/smart-detection.state"
    
    # Logging
    LOG_FILE="$STATE_DIR/smart-detection.log"
    
    log() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
    }
    
    # Initialize state
    init_state() {
      mkdir -p "$STATE_DIR"
      
      if [[ ! -f "$DETECTION_STATE" ]]; then
        cat > "$DETECTION_STATE" <<EOF
    {
      "lastWindowTitle": "",
      "lastWindowClass": "",
      "lastWindowPid": "",
      "lastActivityTime": $(date +%s),
      "lastStepTime": $(date +%s),
      "clickCluster": {
        "centerX": 0,
        "centerY": 0,
        "count": 0,
        "lastClickTime": 0
      },
      "isIdle": false
    }
    EOF
      fi
    }
    
    # Get current window information
    get_window_info() {
      local display_protocol="$(detect_display_protocol)"
      
      if [[ "$display_protocol" == "x11" ]]; then
        local active_window=$(${pkgs.xdotool}/bin/xdotool getactivewindow 2>/dev/null || echo "")
        
        if [[ -n "$active_window" ]]; then
          local title=$(${pkgs.xdotool}/bin/xdotool getwindowname "$active_window" 2>/dev/null || echo "Unknown")
          local class=$(${pkgs.xdotool}/bin/xdotool getwindowclassname "$active_window" 2>/dev/null || echo "Unknown")
          local pid=$(${pkgs.xdotool}/bin/xdotool getwindowpid "$active_window" 2>/dev/null || echo "0")
          
          echo "{\"title\":\"$title\",\"class\":\"$class\",\"pid\":\"$pid\"}"
        else
          echo "{\"title\":\"Unknown\",\"class\":\"Unknown\",\"pid\":\"0\"}"
        fi
      elif [[ "$display_protocol" == "wayland" ]]; then
        # Wayland: Use sway/hyprland specific commands
        if command -v swaymsg &>/dev/null; then
          local info=$(${pkgs.sway}/bin/swaymsg -t get_tree | ${pkgs.jq}/bin/jq -r '.. | select(.focused? == true) | {title: .name, class: .app_id, pid: .pid}')
          echo "$info"
        else
          echo "{\"title\":\"Unknown\",\"class\":\"Unknown\",\"pid\":\"0\"}"
        fi
      else
        echo "{\"title\":\"Unknown\",\"class\":\"Unknown\",\"pid\":\"0\"}"
      fi
    }
    
    # Detect display protocol
    detect_display_protocol() {
      if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
        echo "wayland"
      elif [[ -n "''${DISPLAY:-}" ]]; then
        echo "x11"
      else
        echo "unknown"
      fi
    }
    
    # Get Wayland idle time
    get_wayland_idle_time() {
      local idle_time=0
      
      # Try different Wayland compositor methods
      
      # Method 1: Sway/i3 via swaymsg
      if command -v swaymsg &>/dev/null; then
        # Sway doesn't directly provide idle time, but we can use swayidle
        # For now, we'll track last activity time manually
        idle_time=$(get_wayland_idle_from_state)
        echo "$idle_time"
        return
      fi
      
      # Method 2: Hyprland via hyprctl
      if command -v hyprctl &>/dev/null; then
        # Hyprland can provide some activity info
        local last_activity=$(hyprctl activewindow -j 2>/dev/null | ${pkgs.jq}/bin/jq -r '.pid // 0')
        if [[ "$last_activity" != "0" ]]; then
          idle_time=$(get_wayland_idle_from_state)
        else
          idle_time=999999  # Very large number if no active window
        fi
        echo "$idle_time"
        return
      fi
      
      # Method 3: wlr-randr (for wlroots-based compositors)
      if command -v wlr-randr &>/dev/null; then
        # Use state-based tracking
        idle_time=$(get_wayland_idle_from_state)
        echo "$idle_time"
        return
      fi
      
      # Method 4: Generic fallback using DBus (if available)
      if command -v dbus-send &>/dev/null; then
        # Try to get session idle time from logind
        idle_time=$(dbus-send --print-reply --dest=org.freedesktop.login1 \
          /org/freedesktop/login1/session/auto \
          org.freedesktop.DBus.Properties.Get \
          string:org.freedesktop.login1.Session string:IdleHint 2>/dev/null | \
          ${pkgs.gawk}/bin/awk '/boolean/ {print $2}' || echo "0")
        
        if [[ "$idle_time" == "true" ]]; then
          idle_time=999999  # Treat as very idle
        else
          idle_time=$(get_wayland_idle_from_state)
        fi
        echo "$idle_time"
        return
      fi
      
      # Fallback: State-based tracking
      idle_time=$(get_wayland_idle_from_state)
      echo "$idle_time"
    }
    
    # Get idle time from state (fallback for Wayland)
    get_wayland_idle_from_state() {
      local current_time=$(date +%s)
      local last_activity_time=$(${pkgs.jq}/bin/jq -r '.lastActivityTime' "$DETECTION_STATE" 2>/dev/null || echo "$current_time")
      local idle_time=$((current_time - last_activity_time))
      echo "$idle_time"
    }
    
    # Update Wayland activity timestamp
    update_wayland_activity() {
      local current_time=$(date +%s)
      ${pkgs.jq}/bin/jq --arg time "$current_time" \
                       '.lastActivityTime = ($time | tonumber)' \
                       "$DETECTION_STATE" > "$DETECTION_STATE.tmp" 2>/dev/null || return
      mv "$DETECTION_STATE.tmp" "$DETECTION_STATE"
    }
    
    # Check if window title changed
    check_window_title_change() {
      [[ "$WINDOW_TITLE_CHANGE" != "true" ]] && return 1
      
      local current_info=$(get_window_info)
      local current_title=$(echo "$current_info" | ${pkgs.jq}/bin/jq -r '.title')
      local current_class=$(echo "$current_info" | ${pkgs.jq}/bin/jq -r '.class')
      
      local last_title=$(${pkgs.jq}/bin/jq -r '.lastWindowTitle' "$DETECTION_STATE")
      local last_class=$(${pkgs.jq}/bin/jq -r '.lastWindowClass' "$DETECTION_STATE")
      local last_step_time=$(${pkgs.jq}/bin/jq -r '.lastStepTime' "$DETECTION_STATE")
      local current_time=$(date +%s)
      
      # Check if title changed and enough time has passed
      if [[ "$current_title" != "$last_title" ]] && [[ "$current_class" != "$last_class" ]]; then
        local time_diff=$((current_time - last_step_time))
        
        if [[ $time_diff -ge $TITLE_CHANGE_DELAY ]]; then
          log "Window title changed: '$last_title' -> '$current_title' (class: $current_class)"
          
          # Update state
          ${pkgs.jq}/bin/jq --arg title "$current_title" \
                           --arg class "$current_class" \
                           --arg time "$current_time" \
                           '.lastWindowTitle = $title | .lastWindowClass = $class | .lastStepTime = ($time | tonumber)' \
                           "$DETECTION_STATE" > "$DETECTION_STATE.tmp"
          mv "$DETECTION_STATE.tmp" "$DETECTION_STATE"
          
          return 0
        fi
      fi
      
      return 1
    }
    
    # Check for idle state
    check_idle_state() {
      [[ "$IDLE_DETECTION" != "true" ]] && return 1
      
      local display_protocol="$(detect_display_protocol)"
      local idle_time=0
      
      if [[ "$display_protocol" == "x11" ]]; then
        idle_time=$(${pkgs.xprintidle}/bin/xprintidle 2>/dev/null || echo "0")
        idle_time=$((idle_time / 1000))  # Convert to seconds
      elif [[ "$display_protocol" == "wayland" ]]; then
        # Wayland idle detection
        idle_time=$(get_wayland_idle_time)
      fi
      
      local was_idle=$(${pkgs.jq}/bin/jq -r '.isIdle' "$DETECTION_STATE")
      local is_idle="false"
      
      if [[ $idle_time -ge $IDLE_THRESHOLD ]]; then
        is_idle="true"
        
        # Transition from active to idle
        if [[ "$was_idle" == "false" ]]; then
          log "User became idle (idle time: ''${idle_time}s)"
          
          # Update state
          ${pkgs.jq}/bin/jq '.isIdle = true' "$DETECTION_STATE" > "$DETECTION_STATE.tmp"
          mv "$DETECTION_STATE.tmp" "$DETECTION_STATE"
          
          return 0
        fi
      else
        # Transition from idle to active
        if [[ "$was_idle" == "true" ]]; then
          log "User became active again (idle time: ''${idle_time}s)"
          
          # Update state
          local current_time=$(date +%s)
          ${pkgs.jq}/bin/jq --arg time "$current_time" \
                           '.isIdle = false | .lastActivityTime = ($time | tonumber) | .lastStepTime = ($time | tonumber)' \
                           "$DETECTION_STATE" > "$DETECTION_STATE.tmp"
          mv "$DETECTION_STATE.tmp" "$DETECTION_STATE"
          
          return 0
        fi
      fi
      
      return 1
    }
    
    # Check click clustering
    check_click_clustering() {
      [[ "$CLICK_CLUSTERING" != "true" ]] && return 1
      
      # This function is called by the mouse tracking system
      # It updates the click cluster state
      
      local x=''${1:-0}
      local y=''${2:-0}
      local current_time=$(date +%s)
      
      local center_x=$(${pkgs.jq}/bin/jq -r '.clickCluster.centerX' "$DETECTION_STATE")
      local center_y=$(${pkgs.jq}/bin/jq -r '.clickCluster.centerY' "$DETECTION_STATE")
      local count=$(${pkgs.jq}/bin/jq -r '.clickCluster.count' "$DETECTION_STATE")
      local last_click_time=$(${pkgs.jq}/bin/jq -r '.clickCluster.lastClickTime' "$DETECTION_STATE")
      
      # Calculate distance from cluster center
      local distance=$(echo "sqrt(($x - $center_x)^2 + ($y - $center_y)^2)" | ${pkgs.bc}/bin/bc -l)
      local time_diff=$((current_time - last_click_time))
      
      # Check if click is within cluster or timeout
      if (( $(echo "$distance <= $CLUSTER_RADIUS" | ${pkgs.bc}/bin/bc -l) )) && [[ $time_diff -le $CLUSTER_TIMEOUT ]]; then
        # Add to cluster
        count=$((count + 1))
        
        # Update cluster center (moving average)
        center_x=$(echo "($center_x * ($count - 1) + $x) / $count" | ${pkgs.bc}/bin/bc -l)
        center_y=$(echo "($center_y * ($count - 1) + $y) / $count" | ${pkgs.bc}/bin/bc -l)
        
        log "Click added to cluster at ($x,$y), cluster size: $count"
      else
        # Start new cluster
        if [[ $count -ge 3 ]]; then
          log "Click cluster detected: $count clicks at (${center_x},${center_y})"
          
          # Reset cluster and trigger step
          ${pkgs.jq}/bin/jq --arg x "$x" \
                           --arg y "$y" \
                           --arg time "$current_time" \
                           '.clickCluster = {centerX: ($x | tonumber), centerY: ($y | tonumber), count: 1, lastClickTime: ($time | tonumber)} | .lastStepTime = ($time | tonumber)' \
                           "$DETECTION_STATE" > "$DETECTION_STATE.tmp"
          mv "$DETECTION_STATE.tmp" "$DETECTION_STATE"
          
          return 0
        else
          # Just reset cluster
          center_x=$x
          center_y=$y
          count=1
        fi
      fi
      
      # Update state
      ${pkgs.jq}/bin/jq --arg x "$center_x" \
                       --arg y "$center_y" \
                       --arg count "$count" \
                       --arg time "$current_time" \
                       '.clickCluster = {centerX: ($x | tonumber), centerY: ($y | tonumber), count: ($count | tonumber), lastClickTime: ($time | tonumber)}' \
                       "$DETECTION_STATE" > "$DETECTION_STATE.tmp"
      mv "$DETECTION_STATE.tmp" "$DETECTION_STATE"
      
      return 1
    }
    
    # Check activity-based triggers
    check_activity_triggers() {
      [[ "$ACTIVITY_TRIGGERS" != "true" ]] && return 1
      
      local last_activity_time=$(${pkgs.jq}/bin/jq -r '.lastActivityTime' "$DETECTION_STATE")
      local last_step_time=$(${pkgs.jq}/bin/jq -r '.lastStepTime' "$DETECTION_STATE")
      local current_time=$(date +%s)
      
      local activity_gap=$((current_time - last_activity_time))
      local step_gap=$((current_time - last_step_time))
      
      # Trigger step if there's been sustained activity and enough time since last step
      if [[ $activity_gap -ge $MIN_ACTIVITY_GAP ]] && [[ $step_gap -ge $MIN_ACTIVITY_GAP ]]; then
        log "Activity trigger: sustained activity for ''${activity_gap}s"
        
        # Update state
        ${pkgs.jq}/bin/jq --arg time "$current_time" \
                         '.lastStepTime = ($time | tonumber)' \
                         "$DETECTION_STATE" > "$DETECTION_STATE.tmp"
        mv "$DETECTION_STATE.tmp" "$DETECTION_STATE"
        
        return 0
      fi
      
      return 1
    }
    
    # Main monitoring loop
    monitor() {
      init_state
      log "Smart detection started"
      
      while true; do
        # Check window title change
        if check_window_title_change; then
          echo "TRIGGER:window_title_change"
        fi
        
        # Check idle state
        if check_idle_state; then
          echo "TRIGGER:idle_state_change"
        fi
        
        # Check activity triggers
        if check_activity_triggers; then
          echo "TRIGGER:activity_burst"
        fi
        
        # Sleep before next check
        sleep 1
      done
    }
    
    # Handle click events (called by mouse tracking)
    handle_click() {
      init_state
      local x=''${1:-0}
      local y=''${2:-0}
      
      if check_click_clustering "$x" "$y"; then
        echo "TRIGGER:click_cluster"
      fi
    }
    
    # Command handling
    case "''${1:-monitor}" in
      monitor)
        monitor
        ;;
      click)
        handle_click "''${2:-0}" "''${3:-0}"
        ;;
      status)
        init_state
        cat "$DETECTION_STATE" | ${pkgs.jq}/bin/jq '.'
        ;;
      reset)
        rm -f "$DETECTION_STATE"
        log "Smart detection state reset"
        echo "State reset"
        ;;
      *)
        echo "Usage: $0 {monitor|click <x> <y>|status|reset}"
        exit 1
        ;;
    esac
  '';
  
  # Integration functions
  integrationFunctions = ''
    # Smart detection integration with main recorder
    
    smart_detection_start() {
      if [[ "''${SMART_DETECTION_ENABLED:-false}" == "true" ]]; then
        chronicle-smart-detection monitor > "$STATE_DIR/smart-detection.pipe" 2>&1 &
        echo $! > "$STATE_DIR/smart-detection.pid"
        log "INFO" "Smart detection started (PID: $(cat "$STATE_DIR/smart-detection.pid"))"
      fi
    }
    
    smart_detection_stop() {
      if [[ -f "$STATE_DIR/smart-detection.pid" ]]; then
        local pid=$(cat "$STATE_DIR/smart-detection.pid")
        if kill -0 "$pid" 2>/dev/null; then
          kill "$pid"
          log "INFO" "Smart detection stopped"
        fi
        rm -f "$STATE_DIR/smart-detection.pid"
      fi
    }
    
    smart_detection_handle_trigger() {
      local trigger_type="$1"
      local trigger_reason="$2"
      
      case "$trigger_type" in
        window_title_change)
          log "INFO" "Smart detection triggered: Window title changed"
          capture_step "auto" "Window changed: $trigger_reason"
          ;;
        idle_state_change)
          log "INFO" "Smart detection triggered: Idle state changed"
          capture_step "auto" "User activity changed"
          ;;
        click_cluster)
          log "INFO" "Smart detection triggered: Click cluster detected"
          capture_step "auto" "Multiple clicks detected"
          ;;
        activity_burst)
          log "INFO" "Smart detection triggered: Activity burst detected"
          capture_step "auto" "Sustained user activity"
          ;;
        *)
          log "WARN" "Unknown smart detection trigger: $trigger_type"
          ;;
      esac
    }
  '';
}
