{ lib, pkgs }:

{
  # Audio commentary recording using PulseAudio/PipeWire
  
  # Start audio recording
  startAudioRecording = { sessionDir }: ''
    start_audio_recording() {
      local session_dir="${sessionDir}"
      local audio_file="$session_dir/commentary.opus"
      local audio_pid_file="$session_dir/.audio.pid"
      
      # Check if already recording
      if [ -f "$audio_pid_file" ]; then
        local old_pid=$(cat "$audio_pid_file")
        if ps -p "$old_pid" > /dev/null 2>&1; then
          log "Audio recording already in progress (PID: $old_pid)"
          return 0
        fi
      fi
      
      log "Starting audio commentary recording..."
      
      # Detect audio system (PulseAudio or PipeWire)
      if command -v pactl &> /dev/null; then
        # PulseAudio/PipeWire recording
        ${pkgs.ffmpeg}/bin/ffmpeg \
          -f pulse \
          -i default \
          -c:a libopus \
          -b:a 64k \
          -vbr on \
          -compression_level 10 \
          "$audio_file" \
          > "$session_dir/audio.log" 2>&1 &
      elif command -v arecord &> /dev/null; then
        # ALSA fallback
        ${pkgs.alsa-utils}/bin/arecord \
          -f cd \
          -t wav \
          "$session_dir/commentary.wav" \
          > "$session_dir/audio.log" 2>&1 &
      else
        log "Error: No audio recording system found"
        ${pkgs.libnotify}/bin/notify-send "❌ Audio Recording" "No audio system detected" -u critical
        return 1
      fi
      
      local audio_pid=$!
      echo "$audio_pid" > "$audio_pid_file"
      
      log "Audio recording started (PID: $audio_pid)"
      ${pkgs.libnotify}/bin/notify-send "🎤 Audio Commentary" "Recording started" -u low
      
      return 0
    }
  '';
  
  # Stop audio recording
  stopAudioRecording = { sessionDir }: ''
    stop_audio_recording() {
      local session_dir="${sessionDir}"
      local audio_pid_file="$session_dir/.audio.pid"
      
      if [ ! -f "$audio_pid_file" ]; then
        log "No audio recording in progress"
        return 0
      fi
      
      local audio_pid=$(cat "$audio_pid_file")
      
      if ps -p "$audio_pid" > /dev/null 2>&1; then
        log "Stopping audio recording (PID: $audio_pid)..."
        kill -INT "$audio_pid"
        
        # Wait for process to finish (max 10 seconds)
        local timeout=10
        while [ $timeout -gt 0 ] && ps -p "$audio_pid" > /dev/null 2>&1; do
          sleep 1
          ((timeout--))
        done
        
        if ps -p "$audio_pid" > /dev/null 2>&1; then
          kill -9 "$audio_pid"
        fi
        
        rm -f "$audio_pid_file"
        
        # Check for audio file
        local audio_file=""
        if [ -f "$session_dir/commentary.opus" ]; then
          audio_file="$session_dir/commentary.opus"
        elif [ -f "$session_dir/commentary.wav" ]; then
          audio_file="$session_dir/commentary.wav"
        fi
        
        if [ -n "$audio_file" ] && [ -f "$audio_file" ]; then
          local audio_size=$(du -h "$audio_file" | cut -f1)
          log "Audio recording saved: $audio_file ($audio_size)"
          ${pkgs.libnotify}/bin/notify-send "🎤 Audio Commentary" "Recording saved ($audio_size)" -u low
        else
          log "Warning: Audio file not found after stopping recording"
        fi
      else
        log "Audio recording process not running"
        rm -f "$audio_pid_file"
      fi
      
      return 0
    }
  '';
  
  # Pause audio recording
  pauseAudioRecording = { sessionDir }: ''
    pause_audio_recording() {
      local session_dir="${sessionDir}"
      local audio_pid_file="$session_dir/.audio.pid"
      
      if [ ! -f "$audio_pid_file" ]; then
        log "No audio recording in progress"
        return 0
      fi
      
      local audio_pid=$(cat "$audio_pid_file")
      
      if ps -p "$audio_pid" > /dev/null 2>&1; then
        log "Pausing audio recording..."
        kill -STOP "$audio_pid"
        echo "paused" > "$session_dir/.audio.state"
        ${pkgs.libnotify}/bin/notify-send "⏸️ Audio Commentary" "Recording paused" -u low
      fi
      
      return 0
    }
  '';
  
  # Resume audio recording
  resumeAudioRecording = { sessionDir }: ''
    resume_audio_recording() {
      local session_dir="${sessionDir}"
      local audio_pid_file="$session_dir/.audio.pid"
      
      if [ ! -f "$audio_pid_file" ]; then
        log "No audio recording in progress"
        return 0
      fi
      
      local audio_pid=$(cat "$audio_pid_file")
      
      if ps -p "$audio_pid" > /dev/null 2>&1; then
        log "Resuming audio recording..."
        kill -CONT "$audio_pid"
        rm -f "$session_dir/.audio.state"
        ${pkgs.libnotify}/bin/notify-send "▶️ Audio Commentary" "Recording resumed" -u low
      fi
      
      return 0
    }
  '';
  
  # Generate audio waveform visualization
  generateAudioWaveform = { sessionDir }: ''
    generate_audio_waveform() {
      local session_dir="${sessionDir}"
      local waveform_file="$session_dir/waveform.png"
      
      # Find audio file
      local audio_file=""
      if [ -f "$session_dir/commentary.opus" ]; then
        audio_file="$session_dir/commentary.opus"
      elif [ -f "$session_dir/commentary.wav" ]; then
        audio_file="$session_dir/commentary.wav"
      else
        log "No audio file found for waveform generation"
        return 1
      fi
      
      log "Generating audio waveform..."
      
      # Generate waveform using ffmpeg
      ${pkgs.ffmpeg}/bin/ffmpeg \
        -i "$audio_file" \
        -filter_complex "showwavespic=s=1200x200:colors=#007bff" \
        -frames:v 1 \
        "$waveform_file" \
        -y \
        > /dev/null 2>&1
      
      if [ -f "$waveform_file" ]; then
        log "Waveform generated: $waveform_file"
        return 0
      else
        log "Failed to generate waveform"
        return 1
      fi
    }
  '';
  
  # Get audio information
  getAudioInfo = { sessionDir }: ''
    get_audio_info() {
      local session_dir="${sessionDir}"
      
      # Find audio file
      local audio_file=""
      if [ -f "$session_dir/commentary.opus" ]; then
        audio_file="$session_dir/commentary.opus"
      elif [ -f "$session_dir/commentary.wav" ]; then
        audio_file="$session_dir/commentary.wav"
      else
        echo "{}"
        return 0
      fi
      
      # Extract audio metadata
      local duration=$(${pkgs.ffmpeg}/bin/ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$audio_file" 2>/dev/null)
      local size=$(du -h "$audio_file" | cut -f1)
      local codec=$(${pkgs.ffmpeg}/bin/ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$audio_file" 2>/dev/null)
      local sample_rate=$(${pkgs.ffmpeg}/bin/ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "$audio_file" 2>/dev/null)
      
      # Format duration (seconds to HH:MM:SS)
      local duration_formatted=""
      if [ -n "$duration" ]; then
        duration_formatted=$(date -u -d @"$duration" +%H:%M:%S 2>/dev/null || echo "$duration seconds")
      fi
      
      # Output as JSON
      cat << EOF
{
  "file": "$audio_file",
  "duration": "$duration_formatted",
  "size": "$size",
  "codec": "$codec",
  "sample_rate": "$sample_rate"
}
EOF
    }
  '';
  
  # Export audio with report
  exportAudioWithReport = { sessionDir, htmlFile }: ''
    export_audio_with_report() {
      local session_dir="${sessionDir}"
      local html_file="${htmlFile}"
      
      # Find audio file
      local audio_file=""
      local audio_filename=""
      if [ -f "$session_dir/commentary.opus" ]; then
        audio_file="$session_dir/commentary.opus"
        audio_filename="commentary.opus"
      elif [ -f "$session_dir/commentary.wav" ]; then
        audio_file="$session_dir/commentary.wav"
        audio_filename="commentary.wav"
      else
        log "No audio recording found"
        return 0
      fi
      
      # Generate waveform if not exists
      generate_audio_waveform
      
      # Get audio info
      local audio_info=$(get_audio_info)
      local duration=$(echo "$audio_info" | ${pkgs.jq}/bin/jq -r '.duration')
      local size=$(echo "$audio_info" | ${pkgs.jq}/bin/jq -r '.size')
      local codec=$(echo "$audio_info" | ${pkgs.jq}/bin/jq -r '.codec')
      
      # Create HTML section
      local audio_html="<div class='audio-container'>"
      audio_html+="<h2>🎤 Audio Commentary</h2>"
      audio_html+="<div class='audio-meta'>"
      audio_html+="<span><strong>Duration:</strong> $duration</span> | "
      audio_html+="<span><strong>Size:</strong> $size</span> | "
      audio_html+="<span><strong>Codec:</strong> $codec</span>"
      audio_html+="</div>"
      
      # Add waveform if available
      if [ -f "$session_dir/waveform.png" ]; then
        audio_html+="<div class='waveform' style='margin: 20px 0;'>"
        audio_html+="<img src='waveform.png' alt='Audio Waveform' style='width: 100%; max-width: 1200px; border: 1px solid #dee2e6; border-radius: 4px;'>"
        audio_html+="</div>"
      fi
      
      # Add audio player
      audio_html+="<audio controls style='width: 100%; max-width: 1200px; margin: 20px 0;'>"
      audio_html+="<source src='$audio_filename' type='audio/$(echo $audio_filename | sed 's/.*\.//')'>'"
      audio_html+="Your browser does not support audio playback."
      audio_html+="</audio>"
      audio_html+="</div>"
      
      # Inject into HTML after video section (or after metadata)
      ${pkgs.gnused}/bin/sed -i "/<\/div><!-- meta -->/a $audio_html" "$html_file" 2>/dev/null || true
      
      log "Audio player injected into HTML report"
      return 0
    }
  '';
  
  # Test microphone
  testMicrophone = ''
    test_microphone() {
      log "Testing microphone..."
      
      if command -v pactl &> /dev/null; then
        # Check PulseAudio/PipeWire sources
        local sources=$(pactl list sources short 2>/dev/null)
        if [ -z "$sources" ]; then
          log "Error: No audio input devices found"
          ${pkgs.libnotify}/bin/notify-send "❌ Microphone Test" "No input devices found" -u critical
          return 1
        fi
        
        log "Available audio sources:"
        echo "$sources"
        ${pkgs.libnotify}/bin/notify-send "✅ Microphone Test" "Audio input available" -u low
        return 0
      else
        log "Warning: Could not test microphone (pactl not available)"
        return 1
      fi
    }
  '';
}
