{ lib, pkgs, cfg }:

{
  # Desktop notification functions using libnotify
  notifications = ''
    # Send desktop notification
    send_notification() {
      local title="$1"
      local message="$2"
      local urgency="''${3:-normal}"  # low, normal, critical
      local icon="''${4:-dialog-information}"
      
      if command -v notify-send &> /dev/null; then
        ${pkgs.libnotify}/bin/notify-send \
          --app-name="Step Recorder" \
          --urgency="$urgency" \
          --icon="$icon" \
          "$title" \
          "$message"
      else
        # Fallback to echo if notify-send not available
        echo "📢 $title: $message"
      fi
    }
    
    # Notification: Recording started
    notify_recording_started() {
      local session_id="$1"
      send_notification \
        "🔴 Recording Started" \
        "Session: $session_id\nPress F7 or run 'chronicle stop' to end" \
        "normal" \
        "media-record"
    }
    
    # Notification: Recording stopped
    notify_recording_stopped() {
      local session_id="$1"
      local step_count="$2"
      send_notification \
        "⏹️  Recording Stopped" \
        "Session: $session_id\nTotal steps: $step_count\nExporting..." \
        "normal" \
        "media-playback-stop"
    }
    
    # Notification: Step captured
    notify_step_captured() {
      local step_num="$1"
      local description="$2"
      send_notification \
        "📸 Step $step_num Captured" \
        "$description" \
        "low" \
        "camera-photo"
    }
    
    # Notification: Export completed
    notify_export_completed() {
      local session_id="$1"
      local format="$2"
      local output_path="$3"
      send_notification \
        "✅ Export Complete" \
        "Format: $format\nLocation: $output_path" \
        "normal" \
        "emblem-default"
    }
    
    # Notification: Error occurred
    notify_error() {
      local error_msg="$1"
      send_notification \
        "❌ Step Recorder Error" \
        "$error_msg" \
        "critical" \
        "dialog-error"
    }
    
    # Notification: Warning
    notify_warning() {
      local warning_msg="$1"
      send_notification \
        "⚠️  Step Recorder Warning" \
        "$warning_msg" \
        "normal" \
        "dialog-warning"
    }
    
    # Notification: Pause/Resume
    notify_pause() {
      local paused="$1"
      if [ "$paused" = "true" ]; then
        send_notification \
          "⏸️  Recording Paused" \
          "Press F9 to resume" \
          "low" \
          "media-playback-pause"
      else
        send_notification \
          "▶️  Recording Resumed" \
          "Continuing session..." \
          "low" \
          "media-playback-start"
      fi
    }
    
    # Notification: Max steps reached
    notify_max_steps() {
      local max_steps="$1"
      send_notification \
        "⚠️  Maximum Steps Reached" \
        "Reached limit of $max_steps steps.\nRecording will stop automatically." \
        "normal" \
        "dialog-warning"
    }
    
    # Notification: Comment added
    notify_comment_added() {
      local step_num="$1"
      send_notification \
        "💬 Comment Added" \
        "Comment added to step $step_num" \
        "low" \
        "text-x-generic"
    }
    
    # Notification: Session cleanup
    notify_cleanup() {
      local count="$1"
      send_notification \
        "🗑️  Cleanup Complete" \
        "Removed $count old session(s)" \
        "low" \
        "user-trash"
    }
  '';
}
