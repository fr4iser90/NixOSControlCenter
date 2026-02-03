{ lib, pkgs, cfg }:

{
  # Take screenshot using maim (X11)
  takeScreenshot = { stepNum, timestamp, outputDir, sessionId, quality }: ''
    take_screenshot_x11() {
      local step_num="${toString stepNum}"
      local timestamp="$1"
      local step_dir="${outputDir}/$SESSION_ID/steps"
      mkdir -p "$step_dir"
      
      local output_file="$step_dir/step_''${step_num}_''${timestamp}.png"
      
      debug "Taking X11 screenshot: $output_file"
      
      local error_msg
      if error_msg=$(${pkgs.maim}/bin/maim "$output_file" 2>&1); then
        debug "Screenshot saved successfully with maim"
        
        # Apply quality setting if not 100
        if [ "${toString quality}" != "100" ]; then
          ${pkgs.imagemagick}/bin/convert "$output_file" -quality ${toString quality} "$output_file" 2>/dev/null || true
        fi
        
        # Verify file was created
        if [ -f "$output_file" ]; then
          echo "$output_file"
          return 0
        fi
      fi
      
      error "Screenshot failed: $error_msg"
      warn "Step will be recorded without screenshot"
      return 1
    }
  '';

  # Get active window info
  getWindowInfo = ''
    get_window_info_x11() {
      local window_id=$(${pkgs.xorg.xprop}/bin/xprop -root _NET_ACTIVE_WINDOW | awk '{print $5}')
      if [ "$window_id" != "0x0" ]; then
        local window_title=$(${pkgs.xorg.xprop}/bin/xprop -id "$window_id" _NET_WM_NAME | sed -e 's/_NET_WM_NAME(UTF8_STRING) = //' -e 's/"//g')
        local app_name=$(${pkgs.xorg.xprop}/bin/xprop -id "$window_id" WM_CLASS | awk -F'"' '{print $2}')
        echo "$window_title|$app_name"
      else
        echo "Desktop|$DESKTOP_SESSION"
      fi
    }
  '';

  # Monitor for window changes
  monitorWindowChanges = ''
    monitor_window_changes_x11() {
      # Record initial window
      local initial_window=$(get_window_info_x11)
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
        local current_window=$(get_window_info_x11)

        if [ "$current_window" != "$CURRENT_WINDOW" ]; then
          debug "Window changed from '$CURRENT_WINDOW' to '$current_window'"

          win_title=$(echo "$current_window" | cut -d'|' -f1)
          win_app=$(echo "$current_window" | cut -d'|' -f2)

          if is_window_allowed "$win_title" "$win_app"; then
            record_step "window_change" "$current_window"
            save_state
          else
            debug "Window change not recorded (privacy filtered)"
          fi

          CURRENT_WINDOW="$current_window"
        fi
        sleep 0.5
      done
    }
  '';
}
