{ lib, pkgs, cfg }:

{
  # Take screenshot using grim or spectacle (Wayland)
  takeScreenshot = { stepNum, timestamp, outputDir, sessionId, quality }: ''
    take_screenshot_wayland() {
      local step_num="${toString stepNum}"
      local timestamp="$1"
      local step_dir="${outputDir}/$SESSION_ID/steps"
      mkdir -p "$step_dir"
      
      local output_file="$step_dir/step_''${step_num}_''${timestamp}.png"
      
      debug "Taking Wayland screenshot: $output_file"
      
      local error_msg
      
      # Try spectacle first (KDE)
      if command -v ${pkgs.kdePackages.spectacle}/bin/spectacle &> /dev/null; then
        debug "Using spectacle for Wayland screenshot"
        if error_msg=$(${pkgs.kdePackages.spectacle}/bin/spectacle -b -n -o "$output_file" 2>&1); then
          debug "Screenshot saved successfully with spectacle"
          
          if [ -f "$output_file" ]; then
            echo "$output_file"
            return 0
          fi
        fi
      fi
      
      # Try grim (generic Wayland)
      if command -v ${pkgs.grim}/bin/grim &> /dev/null; then
        debug "Using grim for Wayland screenshot"
        if error_msg=$(${pkgs.grim}/bin/grim "$output_file" 2>&1); then
          debug "Screenshot saved successfully with grim"
          
          if [ -f "$output_file" ]; then
            echo "$output_file"
            return 0
          fi
        fi
      fi
      
      error "Screenshot failed: $error_msg"
      warn "Step will be recorded without screenshot"
      return 1
    }
  '';

  # Get window info (limited on Wayland)
  getWindowInfo = ''
    get_window_info_wayland() {
      # Wayland doesn't provide easy window info access
      # Return generic information
      echo "Unknown|$WAYLAND_DISPLAY"
    }
  '';

  # Manual capture mode (Wayland doesn't support auto-monitoring)
  manualCaptureMode = ''
    manual_capture_mode_wayland() {
      log "Manual capture mode (Wayland)"
      log "Use 'chronicle capture' to manually record steps"
      log "Use 'chronicle stop' to finish recording"
      
      # Keep process alive in foreground
      while [ "$RECORDING" = "true" ]; do
        sleep 1
      done
    }
  '';
}
