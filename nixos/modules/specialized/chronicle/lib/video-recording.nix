{ lib, pkgs }:

{
  # Video recording functionality using ffmpeg
  
  # Start video recording
  startVideoRecording = { sessionDir, backend ? "x11" }: ''
    start_video_recording() {
      local session_dir="${sessionDir}"
      local video_file="$session_dir/recording.mp4"
      local video_pid_file="$session_dir/.video.pid"
      
      # Check if already recording
      if [ -f "$video_pid_file" ]; then
        local old_pid=$(cat "$video_pid_file")
        if ps -p "$old_pid" > /dev/null 2>&1; then
          log "Video recording already in progress (PID: $old_pid)"
          return 0
        fi
      fi
      
      log "Starting video recording..."
      
      ${if backend == "x11" then ''
        # X11 video recording with ffmpeg
        DISPLAY=''${DISPLAY:-:0} ${pkgs.ffmpeg}/bin/ffmpeg \
          -f x11grab \
          -video_size $(${pkgs.xorg.xrandr}/bin/xrandr | ${pkgs.gnugrep}/bin/grep '*' | ${pkgs.gawk}/bin/awk '{print $1}' | head -n1) \
          -framerate 30 \
          -i $DISPLAY \
          -c:v libx264 \
          -preset ultrafast \
          -crf 23 \
          -pix_fmt yuv420p \
          "$video_file" \
          > "$session_dir/video.log" 2>&1 &
      '' else ''
        # Wayland video recording with wf-recorder
        ${pkgs.wf-recorder}/bin/wf-recorder \
          -f "$video_file" \
          -c h264_vaapi \
          -d /dev/dri/renderD128 \
          > "$session_dir/video.log" 2>&1 &
      ''}
      
      local video_pid=$!
      echo "$video_pid" > "$video_pid_file"
      
      log "Video recording started (PID: $video_pid)"
      ${pkgs.libnotify}/bin/notify-send "🎥 Video Recording" "Recording started" -u low
      
      return 0
    }
  '';
  
  # Stop video recording
  stopVideoRecording = { sessionDir }: ''
    stop_video_recording() {
      local session_dir="${sessionDir}"
      local video_pid_file="$session_dir/.video.pid"
      
      if [ ! -f "$video_pid_file" ]; then
        log "No video recording in progress"
        return 0
      fi
      
      local video_pid=$(cat "$video_pid_file")
      
      if ps -p "$video_pid" > /dev/null 2>&1; then
        log "Stopping video recording (PID: $video_pid)..."
        kill -INT "$video_pid"
        
        # Wait for process to finish (max 10 seconds)
        local timeout=10
        while [ $timeout -gt 0 ] && ps -p "$video_pid" > /dev/null 2>&1; do
          sleep 1
          ((timeout--))
        done
        
        if ps -p "$video_pid" > /dev/null 2>&1; then
          log "Force killing video recording process..."
          kill -9 "$video_pid"
        fi
        
        rm -f "$video_pid_file"
        
        local video_file="$session_dir/recording.mp4"
        if [ -f "$video_file" ]; then
          local video_size=$(du -h "$video_file" | cut -f1)
          log "Video recording saved: $video_file ($video_size)"
          ${pkgs.libnotify}/bin/notify-send "🎥 Video Recording" "Recording saved ($video_size)" -u low
        else
          log "Warning: Video file not found after stopping recording"
        fi
      else
        log "Video recording process not running"
        rm -f "$video_pid_file"
      fi
      
      return 0
    }
  '';
  
  # Pause video recording
  pauseVideoRecording = { sessionDir }: ''
    pause_video_recording() {
      local session_dir="${sessionDir}"
      local video_pid_file="$session_dir/.video.pid"
      
      if [ ! -f "$video_pid_file" ]; then
        log "No video recording in progress"
        return 0
      fi
      
      local video_pid=$(cat "$video_pid_file")
      
      if ps -p "$video_pid" > /dev/null 2>&1; then
        log "Pausing video recording..."
        kill -STOP "$video_pid"
        echo "paused" > "$session_dir/.video.state"
        ${pkgs.libnotify}/bin/notify-send "⏸️ Video Recording" "Recording paused" -u low
      fi
      
      return 0
    }
  '';
  
  # Resume video recording
  resumeVideoRecording = { sessionDir }: ''
    resume_video_recording() {
      local session_dir="${sessionDir}"
      local video_pid_file="$session_dir/.video.pid"
      
      if [ ! -f "$video_pid_file" ]; then
        log "No video recording in progress"
        return 0
      fi
      
      local video_pid=$(cat "$video_pid_file")
      
      if ps -p "$video_pid" > /dev/null 2>&1; then
        log "Resuming video recording..."
        kill -CONT "$video_pid"
        rm -f "$session_dir/.video.state"
        ${pkgs.libnotify}/bin/notify-send "▶️ Video Recording" "Recording resumed" -u low
      fi
      
      return 0
    }
  '';
  
  # Generate video thumbnail
  generateVideoThumbnail = { sessionDir }: ''
    generate_video_thumbnail() {
      local session_dir="${sessionDir}"
      local video_file="$session_dir/recording.mp4"
      local thumbnail_file="$session_dir/video_thumbnail.jpg"
      
      if [ ! -f "$video_file" ]; then
        log "Video file not found: $video_file"
        return 1
      fi
      
      log "Generating video thumbnail..."
      
      ${pkgs.ffmpeg}/bin/ffmpeg \
        -i "$video_file" \
        -ss 00:00:01 \
        -vframes 1 \
        -vf "scale=320:-1" \
        "$thumbnail_file" \
        -y \
        > /dev/null 2>&1
      
      if [ -f "$thumbnail_file" ]; then
        log "Video thumbnail generated: $thumbnail_file"
        return 0
      else
        log "Failed to generate video thumbnail"
        return 1
      fi
    }
  '';
  
  # Get video information
  getVideoInfo = { sessionDir }: ''
    get_video_info() {
      local session_dir="${sessionDir}"
      local video_file="$session_dir/recording.mp4"
      
      if [ ! -f "$video_file" ]; then
        echo "{}"
        return 0
      fi
      
      # Extract video metadata
      local duration=$(${pkgs.ffmpeg}/bin/ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video_file" 2>/dev/null)
      local size=$(du -h "$video_file" | cut -f1)
      local resolution=$(${pkgs.ffmpeg}/bin/ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$video_file" 2>/dev/null)
      
      # Format duration (seconds to HH:MM:SS)
      local duration_formatted=""
      if [ -n "$duration" ]; then
        duration_formatted=$(date -u -d @"$duration" +%H:%M:%S 2>/dev/null || echo "$duration seconds")
      fi
      
      # Output as JSON
      cat << EOF
{
  "file": "$video_file",
  "duration": "$duration_formatted",
  "size": "$size",
  "resolution": "$resolution"
}
EOF
    }
  '';
  
  # Export video with report
  exportVideoWithReport = { sessionDir, htmlFile }: ''
    export_video_with_report() {
      local session_dir="${sessionDir}"
      local html_file="${htmlFile}"
      local video_file="$session_dir/recording.mp4"
      
      if [ ! -f "$video_file" ]; then
        log "No video recording found"
        return 0
      fi
      
      # Generate thumbnail if not exists
      generate_video_thumbnail
      
      # Get video info
      local video_info=$(get_video_info)
      local duration=$(echo "$video_info" | ${pkgs.jq}/bin/jq -r '.duration')
      local size=$(echo "$video_info" | ${pkgs.jq}/bin/jq -r '.size')
      local resolution=$(echo "$video_info" | ${pkgs.jq}/bin/jq -r '.resolution')
      
      # Inject video player into HTML
      local video_html="<div class='video-container'>"
      video_html+="<h2>🎥 Video Recording</h2>"
      video_html+="<div class='video-meta'>"
      video_html+="<span><strong>Duration:</strong> $duration</span> | "
      video_html+="<span><strong>Size:</strong> $size</span> | "
      video_html+="<span><strong>Resolution:</strong> $resolution</span>"
      video_html+="</div>"
      video_html+="<video controls width='100%' style='max-width: 1200px; margin: 20px 0; border: 1px solid #dee2e6; border-radius: 4px;'>"
      video_html+="<source src='recording.mp4' type='video/mp4'>"
      video_html+="Your browser does not support video playback."
      video_html+="</video>"
      video_html+="</div>"
      
      # Inject into HTML after metadata section
      ${pkgs.gnused}/bin/sed -i "/<\/div><!-- meta -->/a $video_html" "$html_file" 2>/dev/null || true
      
      log "Video player injected into HTML report"
      return 0
    }
  '';
}
