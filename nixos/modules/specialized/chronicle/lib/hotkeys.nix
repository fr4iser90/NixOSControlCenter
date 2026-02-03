{ lib, pkgs, cfg }:

{
  # Global hotkey handler using xbindkeys for X11 or keyd for Wayland
  hotkeyHandler = ''
    # Hotkey configuration
    setup_hotkeys() {
      local hotkey_config="$HOME/.config/chronicle/hotkeys.conf"
      mkdir -p "$(dirname "$hotkey_config")"
      
      cat > "$hotkey_config" << 'HOTKEY_EOF'
# Step Recorder Hotkeys Configuration
# F7: Start/Stop Recording
# F8: Quick Capture
# F9: Pause/Resume
# F10: Add Comment
# Ctrl+Alt+S: Start Recording
# Ctrl+Alt+C: Capture Step
# Ctrl+Alt+P: Pause/Resume

[F7]
action=start_stop_toggle

[F8]
action=quick_capture

[F9]
action=pause_resume

[F10]
action=add_comment

[Control+Alt+s]
action=start_recording

[Control+Alt+c]
action=capture_step

[Control+Alt+p]
action=pause_resume
HOTKEY_EOF
      
      debug "Hotkey configuration created: $hotkey_config"
    }
    
    # Execute hotkey action
    execute_hotkey_action() {
      local action="$1"
      
      case "$action" in
        start_stop_toggle)
          load_state || true
          if [ "$RECORDING" = "true" ]; then
            chronicle stop &
          else
            chronicle start --daemon &
          fi
          ;;
        quick_capture)
          chronicle capture &
          ;;
        pause_resume)
          toggle_pause_resume
          ;;
        add_comment)
          add_comment_dialog
          ;;
        start_recording)
          chronicle start --daemon &
          ;;
        capture_step)
          chronicle capture &
          ;;
      esac
    }
    
    # Global hotkey listener (X11)
    start_hotkey_listener_x11() {
      if command -v xbindkeys &> /dev/null; then
        # Create xbindkeys config
        local xbindkeys_config="$HOME/.config/chronicle/xbindkeysrc"
        cat > "$xbindkeys_config" << 'XBIND_EOF'
# Step Recorder X11 Hotkeys
"chronicle hotkey start_stop_toggle"
  F7
"chronicle hotkey quick_capture"
  F8
"chronicle hotkey pause_resume"
  F9
"chronicle hotkey add_comment"
  F10
"chronicle hotkey start_recording"
  Control+Alt+s
"chronicle hotkey capture_step"
  Control+Alt+c
"chronicle hotkey pause_resume"
  Control+Alt+p
XBIND_EOF
        ${pkgs.xbindkeys}/bin/xbindkeys -f "$xbindkeys_config" &
        debug "X11 hotkey listener started"
      else
        debug "xbindkeys not available, hotkeys disabled"
      fi
    }
    
    # Global hotkey listener (Wayland - using keyd if available)
    start_hotkey_listener_wayland() {
      debug "Wayland hotkey support requires system-level keyd configuration"
      # Note: Wayland hotkeys typically require compositor-specific configuration
      # or a tool like keyd which needs root permissions
    }
  '';
  
  # Hotkey command handler
  hotkeyCommand = ''
    handle_hotkey_command() {
      local action="''${1:-help}"
      execute_hotkey_action "$action"
    }
  '';
}
