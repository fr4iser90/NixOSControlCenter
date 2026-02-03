{ lib, pkgs, cfg ? {} }:

{
  # Multi-monitor detection and management
  multiMonitorSupport = ''
    # Detect all connected monitors
    detect_monitors() {
      local backend="$1"
      local monitors_json="$SESSION_DIR/monitors.json"
      
      if [ "$backend" = "x11" ]; then
        # X11: Use xrandr to detect monitors
        local monitors=$(${pkgs.xorg.xrandr}/bin/xrandr --query | grep " connected" | awk '{print $1}')
        local monitor_count=$(echo "$monitors" | wc -l)
        
        log "Detected $monitor_count monitor(s) via xrandr"
        
        # Build JSON array of monitors with geometry
        echo "[" > "$monitors_json"
        local first=true
        
        while IFS= read -r monitor; do
          [ -z "$monitor" ] && continue
          
          # Get monitor geometry
          local geometry=$(${pkgs.xorg.xrandr}/bin/xrandr --query | grep "^$monitor" | sed 's/.*\([0-9]*x[0-9]*+[0-9]*+[0-9]*\).*/\1/')
          
          if [ -n "$geometry" ]; then
            # Parse geometry: WxH+X+Y
            local width=$(echo "$geometry" | cut -d'x' -f1)
            local height=$(echo "$geometry" | cut -d'x' -f2 | cut -d'+' -f1)
            local offset_x=$(echo "$geometry" | cut -d'+' -f2)
            local offset_y=$(echo "$geometry" | cut -d'+' -f3)
            
            [ "$first" = false ] && echo "," >> "$monitors_json"
            first=false
            
            cat >> "$monitors_json" << EOF
  {
    "name": "$monitor",
    "width": $width,
    "height": $height,
    "offset_x": $offset_x,
    "offset_y": $offset_y,
    "geometry": "$geometry",
    "primary": $(${pkgs.xorg.xrandr}/bin/xrandr --query | grep "^$monitor" | grep -q "primary" && echo "true" || echo "false")
  }
EOF
          fi
        done <<< "$monitors"
        
        echo "]" >> "$monitors_json"
        
      elif [ "$backend" = "wayland" ]; then
        # Wayland: Use wlr-randr or swaymsg
        if command -v wlr-randr &> /dev/null; then
          log "Detecting monitors via wlr-randr"
          # Parse wlr-randr output
          # This is a simplified version - full implementation would parse all output
          echo "[]" > "$monitors_json"
          # TODO: Parse wlr-randr output properly
        elif command -v swaymsg &> /dev/null; then
          log "Detecting monitors via swaymsg"
          ${pkgs.sway}/bin/swaymsg -t get_outputs > "$monitors_json"
        else
          log_warn "No Wayland monitor detection tool available"
          echo "[]" > "$monitors_json"
        fi
      else
        log_warn "Unknown backend: $backend"
        echo "[]" > "$monitors_json"
      fi
      
      log "Monitor configuration saved to $monitors_json"
    }
    
    # Get the monitor containing a specific window
    get_window_monitor() {
      local window_id="$1"
      local backend="$2"
      
      if [ "$backend" = "x11" ]; then
        # Get window position
        local window_info=$(${pkgs.xdotool}/bin/xdotool getwindowgeometry "$window_id" 2>/dev/null)
        local window_x=$(echo "$window_info" | grep "Position:" | awk '{print $2}' | cut -d',' -f1)
        local window_y=$(echo "$window_info" | grep "Position:" | awk '{print $2}' | cut -d',' -f2)
        
        # Find which monitor contains this position
        local monitors_json="$SESSION_DIR/monitors.json"
        if [ -f "$monitors_json" ]; then
          local monitor=$(${pkgs.jq}/bin/jq -r --arg x "$window_x" --arg y "$window_y" '
            .[] | select(
              ($x | tonumber) >= .offset_x and 
              ($x | tonumber) < (.offset_x + .width) and
              ($y | tonumber) >= .offset_y and 
              ($y | tonumber) < (.offset_y + .height)
            ) | .name
          ' "$monitors_json" | head -n1)
          
          if [ -n "$monitor" ]; then
            echo "$monitor"
          else
            # Fallback to primary monitor
            ${pkgs.jq}/bin/jq -r '.[] | select(.primary == true) | .name' "$monitors_json" | head -n1
          fi
        fi
      fi
    }
    
    # Capture screenshot from specific monitor
    capture_monitor_screenshot() {
      local monitor="$1"
      local output_file="$2"
      local backend="$3"
      
      if [ "$backend" = "x11" ]; then
        local monitors_json="$SESSION_DIR/monitors.json"
        if [ -f "$monitors_json" ]; then
          local geometry=$(${pkgs.jq}/bin/jq -r --arg mon "$monitor" '.[] | select(.name == $mon) | .geometry' "$monitors_json")
          
          if [ -n "$geometry" ] && [ "$geometry" != "null" ]; then
            log "Capturing screenshot from monitor $monitor (geometry: $geometry)"
            ${pkgs.maim}/bin/maim -g "$geometry" "$output_file" 2>&1 | while read -r line; do
              log "maim: $line"
            done
          else
            log_warn "Could not find geometry for monitor $monitor, falling back to full screen"
            ${pkgs.maim}/bin/maim "$output_file" 2>&1 | while read -r line; do
              log "maim: $line"
            done
          fi
        fi
      elif [ "$backend" = "wayland" ]; then
        # Wayland: grim can capture specific outputs
        if command -v grim &> /dev/null; then
          ${pkgs.grim}/bin/grim -o "$monitor" "$output_file" 2>&1 | while read -r line; do
            log "grim: $line"
          done
        fi
      fi
    }
    
    # Monitor switch detection (called when active window changes)
    detect_monitor_switch() {
      local window_id="$1"
      local backend="$2"
      local current_monitor_file="$SESSION_DIR/.current_monitor"
      
      local new_monitor=$(get_window_monitor "$window_id" "$backend")
      local old_monitor=""
      
      if [ -f "$current_monitor_file" ]; then
        old_monitor=$(cat "$current_monitor_file")
      fi
      
      if [ -n "$new_monitor" ] && [ "$new_monitor" != "$old_monitor" ]; then
        log "Monitor switch detected: $old_monitor -> $new_monitor"
        echo "$new_monitor" > "$current_monitor_file"
        
        # Record monitor switch event
        return 0  # Switch detected
      fi
      
      return 1  # No switch
    }
    
    # Add monitor info to step metadata
    add_monitor_metadata() {
      local step_json="$1"
      local window_id="$2"
      local backend="$3"
      
      local monitor=$(get_window_monitor "$window_id" "$backend")
      
      if [ -n "$monitor" ]; then
        # Add monitor info to step JSON
        local temp_json=$(mktemp)
        ${pkgs.jq}/bin/jq --arg mon "$monitor" '. + {monitor: $mon}' "$step_json" > "$temp_json"
        mv "$temp_json" "$step_json"
        log "Added monitor metadata: $monitor"
      fi
    }
  '';
}
