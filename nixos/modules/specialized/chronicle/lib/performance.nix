{ lib, pkgs }:

{
  # Screenshot compression and optimization
  optimizeScreenshot = { quality ? 85 }: ''
    optimize_screenshot() {
      local input_file="$1"
      local quality="${toString quality}"
      
      if [ ! -f "$input_file" ]; then
        error "Screenshot file not found: $input_file"
        return 1
      fi
      
      debug "Optimizing screenshot: $input_file (quality: $quality)"
      
      # Get original size
      local original_size=$(stat -f%z "$input_file" 2>/dev/null || stat -c%s "$input_file" 2>/dev/null)
      
      # Create temporary file
      local temp_file="''${input_file}.tmp"
      
      # Optimize using ImageMagick with progressive JPEG and strip metadata
      if ${pkgs.imagemagick}/bin/convert "$input_file" \
          -strip \
          -interlace Plane \
          -quality "$quality" \
          -sampling-factor 4:2:0 \
          "$temp_file" 2>/dev/null; then
        
        # Get new size
        local new_size=$(stat -f%z "$temp_file" 2>/dev/null || stat -c%s "$temp_file" 2>/dev/null)
        
        # Only replace if compression was successful
        if [ "$new_size" -lt "$original_size" ]; then
          mv "$temp_file" "$input_file"
          local saved=$((original_size - new_size))
          local percent=$((saved * 100 / original_size))
          debug "Compressed screenshot: saved $saved bytes ($percent%)"
        else
          rm -f "$temp_file"
          debug "Skipping compression: no size reduction"
        fi
      else
        rm -f "$temp_file"
        warn "Screenshot optimization failed, keeping original"
      fi
    }
  '';

  # Memory management - cleanup old sessions
  cleanupOldSessions = { maxSessions ? 50, maxAgeDays ? 30 }: ''
    cleanup_old_sessions() {
      local output_dir="$1"
      local max_sessions=${toString maxSessions}
      local max_age_days=${toString maxAgeDays}
      
      if [ ! -d "$output_dir" ]; then
        debug "Output directory does not exist: $output_dir"
        return 0
      fi
      
      debug "Running session cleanup (max: $max_sessions sessions, max age: $max_age_days days)"
      
      # Count total sessions
      local total_sessions=$(find "$output_dir" -maxdepth 1 -type d -name "session_*" | wc -l)
      
      if [ "$total_sessions" -le "$max_sessions" ]; then
        debug "Session count within limits ($total_sessions/$max_sessions)"
      else
        # Remove oldest sessions beyond limit
        local to_remove=$((total_sessions - max_sessions))
        debug "Removing $to_remove oldest sessions"
        
        find "$output_dir" -maxdepth 1 -type d -name "session_*" -printf '%T@ %p\n' | \
          sort -n | \
          head -n "$to_remove" | \
          cut -d' ' -f2- | \
          while read -r session_dir; do
            log "Removing old session: $(basename "$session_dir")"
            rm -rf "$session_dir"
          done
      fi
      
      # Remove sessions older than max age
      if [ "$max_age_days" -gt 0 ]; then
        debug "Removing sessions older than $max_age_days days"
        find "$output_dir" -maxdepth 1 -type d -name "session_*" -mtime +$max_age_days -exec rm -rf {} \;
      fi
      
      # Calculate total disk usage
      local disk_usage=$(du -sh "$output_dir" 2>/dev/null | cut -f1)
      log "Current disk usage: $disk_usage"
    }
  '';

  # Background export processing
  backgroundExport = ''
    background_export() {
      local session_dir="$1"
      local format="$2"
      
      log "Starting background export to $format format..."
      
      # Create background job
      (
        # Export with nice priority to not impact system
        nice -n 10 bash -c "
          export_recording '$session_dir' '$format'
          notify 'Export Complete' 'Successfully exported to $format format' 'info'
        " &
      ) &
      
      local bg_pid=$!
      log "Export running in background (PID: $bg_pid)"
      
      # Store PID for monitoring
      echo "$bg_pid" > "$session_dir/.export.pid"
    }
  '';

  # Lazy loading support - generate thumbnail index
  generateThumbnails = { thumbnailSize ? 300 }: ''
    generate_thumbnails() {
      local session_dir="$1"
      local steps_dir="$session_dir/steps"
      local thumbs_dir="$session_dir/thumbnails"
      local thumb_size=${toString thumbnailSize}
      
      if [ ! -d "$steps_dir" ]; then
        warn "Steps directory not found: $steps_dir"
        return 1
      fi
      
      mkdir -p "$thumbs_dir"
      
      debug "Generating thumbnails (size: ''${thumb_size}px)"
      
      local count=0
      for screenshot in "$steps_dir"/step_*.png; do
        if [ -f "$screenshot" ]; then
          local basename=$(basename "$screenshot")
          local thumb_file="$thumbs_dir/$basename"
          
          # Generate thumbnail if it doesn't exist
          if [ ! -f "$thumb_file" ]; then
            ${pkgs.imagemagick}/bin/convert "$screenshot" \
              -resize "''${thumb_size}x''${thumb_size}>" \
              -quality 75 \
              "$thumb_file" 2>/dev/null && \
              count=$((count + 1))
          fi
        fi
      done
      
      if [ $count -gt 0 ]; then
        log "Generated $count thumbnails"
      fi
    }
  '';

  # Resource monitoring during recording
  monitorResources = ''
    monitor_resources() {
      # Get memory usage
      local mem_usage=$(ps -o rss= -p $$ 2>/dev/null | awk '{print int($1/1024)}')
      
      # Get CPU usage (approximate)
      local cpu_usage=$(ps -o %cpu= -p $$ 2>/dev/null | awk '{print int($1)}')
      
      # Check if we're using too much memory (> 500MB is concerning)
      if [ "$mem_usage" -gt 500 ]; then
        warn "High memory usage: ''${mem_usage}MB"
      fi
      
      # Check if we're using too much CPU (> 20% when idle is concerning)
      if [ "$cpu_usage" -gt 20 ] && [ "$RECORDING_ACTIVE" != "true" ]; then
        warn "High CPU usage while idle: ''${cpu_usage}%"
      fi
      
      debug "Resource usage: CPU: ''${cpu_usage}%, Memory: ''${mem_usage}MB"
    }
  '';

  # Batch screenshot processing
  batchProcessScreenshots = ''
    batch_process_screenshots() {
      local session_dir="$1"
      local steps_dir="$session_dir/steps"
      
      if [ ! -d "$steps_dir" ]; then
        return 0
      fi
      
      log "Starting batch screenshot processing..."
      
      local processed=0
      local total=$(find "$steps_dir" -name "step_*.png" | wc -l)
      
      # Process screenshots in parallel (4 at a time)
      find "$steps_dir" -name "step_*.png" -print0 | \
        xargs -0 -P 4 -I {} bash -c '
          optimize_screenshot "{}"
        ' && processed=$total
      
      log "Batch processing complete: $processed/$total screenshots optimized"
    }
  '';

  # Session cache management
  cacheManagement = ''
    manage_cache() {
      local cache_dir="$STATE_DIR/cache"
      mkdir -p "$cache_dir"
      
      # Clear cache older than 7 days
      find "$cache_dir" -type f -mtime +7 -delete 2>/dev/null
      
      # Limit cache size to 100MB
      local cache_size=$(du -sm "$cache_dir" 2>/dev/null | cut -f1)
      if [ "$cache_size" -gt 100 ]; then
        warn "Cache size exceeded 100MB, clearing old entries"
        find "$cache_dir" -type f -printf '%T@ %p\n' | \
          sort -n | \
          head -n $((cache_size - 50)) | \
          cut -d' ' -f2- | \
          xargs rm -f
      fi
    }
  '';
}
