{ lib, pkgs, cfg }:

{
  # Mouse click visualization and tracking
  mouseTracking = ''
    # Draw click visualization overlay
    draw_click_overlay() {
      local x="$1"
      local y="$2"
      local button="''${3:-left}"  # left, right, middle
      local color="''${4:-red}"
      
      # Color based on button
      case "$button" in
        left|1)
          color="red"
          ;;
        right|3)
          color="blue"
          ;;
        middle|2)
          color="yellow"
          ;;
      esac
      
      # Create click animation using ImageMagick
      # This creates a temporary overlay that gets composited onto screenshots
      local click_overlay="/tmp/click_overlay_$$.png"
      
      # Create a semi-transparent circle at click position
      ${pkgs.imagemagick}/bin/convert -size 60x60 xc:none \
        -fill "$color" -stroke "$color" -strokewidth 3 \
        -draw "circle 30,30 30,5" \
        -alpha set -channel A -evaluate multiply 0.5 \
        "$click_overlay"
      
      # Store click metadata for later composition
      echo "$x,$y,$button,$(date +%s%N)" >> "$OUTPUT_DIR/$SESSION_ID/.clicks.log"
      
      debug "Click recorded at ($x,$y) button=$button"
    }
    
    # Monitor mouse clicks (X11)
    monitor_mouse_clicks_x11() {
      # Use xinput to track mouse events
      ${pkgs.xorg.xinput}/bin/xinput test-xi2 --root 2>/dev/null | \
      while read -r line; do
        if echo "$line" | grep -q "ButtonPress"; then
          # Extract button number
          local button=$(echo "$line" | grep -oP 'detail: \K\d+')
          
          # Get cursor position
          eval $(${pkgs.xdotool}/bin/xdotool getmouselocation --shell)
          
          # Draw overlay
          draw_click_overlay "$X" "$Y" "$button"
          
          # Trigger step capture if enabled
          if [ "${toString cfg.recording.autoTrigger}" = "true" ]; then
            record_step "click" "$(get_window_info_x11)"
          fi
        fi
      done &
      
      CLICK_MONITOR_PID=$!
      debug "Mouse click monitor started (PID: $CLICK_MONITOR_PID)"
    }
    
    # Monitor right-clicks specifically
    monitor_right_clicks() {
      ${pkgs.xorg.xinput}/bin/xinput test-xi2 --root 2>/dev/null | \
      while read -r line; do
        if echo "$line" | grep -q "ButtonPress.*detail: 3"; then
          eval $(${pkgs.xdotool}/bin/xdotool getmouselocation --shell)
          draw_click_overlay "$X" "$Y" "right"
          record_step "right-click" "$(get_window_info_x11)"
        fi
      done &
      
      RIGHT_CLICK_MONITOR_PID=$!
    }
    
    # Apply click overlays to screenshot
    apply_click_overlays() {
      local screenshot="$1"
      local timestamp="$2"
      
      if [ ! -f "$OUTPUT_DIR/$SESSION_ID/.clicks.log" ]; then
        return 0
      fi
      
      # Get clicks within last 2 seconds
      local now=$(date +%s%N)
      local threshold=$((now - 2000000000))  # 2 seconds in nanoseconds
      
      while IFS=',' read -r x y button click_time; do
        if [ "$click_time" -gt "$threshold" ]; then
          # Composite click overlay onto screenshot
          local color="red"
          case "$button" in
            right|3) color="blue" ;;
            middle|2) color="yellow" ;;
          esac
          
          # Draw circle at click position
          ${pkgs.imagemagick}/bin/convert "$screenshot" \
            -fill none -stroke "$color" -strokewidth 4 \
            -draw "circle $x,$y $((x+25)),$y" \
            "$screenshot"
        fi
      done < "$OUTPUT_DIR/$SESSION_ID/.clicks.log"
    }
    
    # Track mouse movement (experimental)
    track_mouse_movement() {
      local prev_x=0
      local prev_y=0
      local move_count=0
      
      while [ "$RECORDING" = "true" ]; do
        eval $(${pkgs.xdotool}/bin/xdotool getmouselocation --shell 2>/dev/null)
        
        if [ "$X" != "$prev_x" ] || [ "$Y" != "$prev_y" ]; then
          # Significant movement detected
          local distance=$(echo "sqrt(($X-$prev_x)^2 + ($Y-$prev_y)^2)" | ${pkgs.bc}/bin/bc)
          
          if [ "$(echo "$distance > 50" | ${pkgs.bc}/bin/bc)" -eq 1 ]; then
            move_count=$((move_count + 1))
            echo "$(date +%s),$prev_x,$prev_y,$X,$Y" >> "$OUTPUT_DIR/$SESSION_ID/.mouse_trail.log"
            prev_x=$X
            prev_y=$Y
          fi
        fi
        
        sleep 0.1
      done &
      
      MOUSE_TRACKER_PID=$!
    }
    
    # Cleanup mouse tracking
    cleanup_mouse_tracking() {
      if [ -n "''${CLICK_MONITOR_PID:-}" ]; then
        kill $CLICK_MONITOR_PID 2>/dev/null || true
      fi
      if [ -n "''${RIGHT_CLICK_MONITOR_PID:-}" ]; then
        kill $RIGHT_CLICK_MONITOR_PID 2>/dev/null || true
      fi
      if [ -n "''${MOUSE_TRACKER_PID:-}" ]; then
        kill $MOUSE_TRACKER_PID 2>/dev/null || true
      fi
    }
  '';
  
  # Scroll event detection
  scrollDetection = ''
    # Detect scroll events (X11)
    monitor_scroll_events() {
      ${pkgs.xorg.xinput}/bin/xinput test-xi2 --root 2>/dev/null | \
      while read -r line; do
        # Button 4 = scroll up, Button 5 = scroll down
        if echo "$line" | grep -qE "ButtonPress.*(detail: 4|detail: 5)"; then
          local direction="down"
          echo "$line" | grep -q "detail: 4" && direction="up"
          
          eval $(${pkgs.xdotool}/bin/xdotool getmouselocation --shell)
          local window_info=$(get_window_info_x11)
          
          record_step "scroll-$direction" "$window_info"
          debug "Scroll $direction detected at ($X,$Y)"
        fi
      done &
      
      SCROLL_MONITOR_PID=$!
    }
  '';
  
  # Drag and drop detection
  dragDropDetection = ''
    # Detect drag and drop operations (X11)
    monitor_drag_drop() {
      local dragging=false
      local drag_start_x=0
      local drag_start_y=0
      
      ${pkgs.xorg.xinput}/bin/xinput test-xi2 --root 2>/dev/null | \
      while read -r line; do
        if echo "$line" | grep -q "ButtonPress.*detail: 1"; then
          dragging=true
          eval $(${pkgs.xdotool}/bin/xdotool getmouselocation --shell)
          drag_start_x=$X
          drag_start_y=$Y
        elif echo "$line" | grep -q "ButtonRelease.*detail: 1"; then
          if [ "$dragging" = "true" ]; then
            eval $(${pkgs.xdotool}/bin/xdotool getmouselocation --shell)
            local distance=$(echo "sqrt(($X-$drag_start_x)^2 + ($Y-$drag_start_y)^2)" | ${pkgs.bc}/bin/bc)
            
            # If moved more than 20 pixels, consider it a drag
            if [ "$(echo "$distance > 20" | ${pkgs.bc}/bin/bc)" -eq 1 ]; then
              record_step "drag-drop" "From ($drag_start_x,$drag_start_y) to ($X,$Y)"
              debug "Drag and drop detected: ''${distance}px"
            fi
            
            dragging=false
          fi
        fi
      done &
      
      DRAG_DROP_MONITOR_PID=$!
    }
  '';
}
