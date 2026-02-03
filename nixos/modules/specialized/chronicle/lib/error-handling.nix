{ lib, pkgs, cfg ? {} }:

{
  # Comprehensive error handling and logging
  errorHandling = ''
    # Error levels
    ERROR_LEVEL_DEBUG=0
    ERROR_LEVEL_INFO=1
    ERROR_LEVEL_WARN=2
    ERROR_LEVEL_ERROR=3
    ERROR_LEVEL_CRITICAL=4
    
    # Current log level (default: INFO)
    CURRENT_LOG_LEVEL=''${CHRONICLE_LOG_LEVEL:-1}
    
    # Log file
    ERROR_LOG_FILE="$HOME/.local/share/chronicle/error.log"
    
    # Initialize error logging
    init_error_logging() {
      mkdir -p "$(dirname "$ERROR_LOG_FILE")"
      
      # Rotate log if too large (>10MB)
      if [ -f "$ERROR_LOG_FILE" ]; then
        local size=$(stat -f%z "$ERROR_LOG_FILE" 2>/dev/null || stat -c%s "$ERROR_LOG_FILE" 2>/dev/null || echo 0)
        if [ "$size" -gt 10485760 ]; then
          mv "$ERROR_LOG_FILE" "$ERROR_LOG_FILE.old"
          log "Rotated error log (size: $size bytes)"
        fi
      fi
      
      log "Error logging initialized: $ERROR_LOG_FILE"
    }
    
    # Enhanced logging functions with levels
    log_with_level() {
      local level="$1"
      local level_num="$2"
      local message="$3"
      local color="$4"
      
      # Check if we should log this level
      if [ "$level_num" -lt "$CURRENT_LOG_LEVEL" ]; then
        return
      fi
      
      local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
      local log_entry="[$timestamp] [$level] $message"
      
      # Console output with color
      if [ -t 1 ]; then
        echo -e "''${color}$log_entry\033[0m"
      else
        echo "$log_entry"
      fi
      
      # File output
      echo "$log_entry" >> "$ERROR_LOG_FILE"
    }
    
    log_debug() {
      log_with_level "DEBUG" "$ERROR_LEVEL_DEBUG" "$1" "\033[0;36m"
    }
    
    log() {
      log_with_level "INFO" "$ERROR_LEVEL_INFO" "$1" "\033[0;32m"
    }
    
    log_warn() {
      log_with_level "WARN" "$ERROR_LEVEL_WARN" "$1" "\033[0;33m"
    }
    
    log_error() {
      log_with_level "ERROR" "$ERROR_LEVEL_ERROR" "$1" "\033[0;31m"
    }
    
    log_critical() {
      log_with_level "CRITICAL" "$ERROR_LEVEL_CRITICAL" "$1" "\033[1;31m"
    }
    
    # Error handler with retry logic
    handle_error() {
      local error_code="$1"
      local operation="$2"
      local context="$3"
      
      log_error "Operation failed: $operation (code: $error_code)"
      log_error "Context: $context"
      
      # Record error in session if available
      if [ -n "$SESSION_DIR" ] && [ -d "$SESSION_DIR" ]; then
        local errors_file="$SESSION_DIR/errors.json"
        local error_entry="{
          \"timestamp\": \"$(date -Iseconds)\",
          \"code\": $error_code,
          \"operation\": \"$operation\",
          \"context\": \"$context\"
        }"
        
        if [ ! -f "$errors_file" ]; then
          echo "[]" > "$errors_file"
        fi
        
        # Append error to array
        local temp_errors=$(mktemp)
        ${pkgs.jq}/bin/jq --argjson err "$error_entry" '. += [$err]' "$errors_file" > "$temp_errors"
        mv "$temp_errors" "$errors_file"
      fi
      
      # Notify user based on severity
      case "$error_code" in
        1|2)
          # Minor errors - just log
          ;;
        3|4|5)
          # Moderate errors - notify
          ${pkgs.libnotify}/bin/notify-send "Step Recorder Error" "$operation failed: $context" --urgency=normal
          ;;
        *)
          # Critical errors - notify with urgency
          ${pkgs.libnotify}/bin/notify-send "Step Recorder Critical Error" "$operation failed: $context" --urgency=critical
          ;;
      esac
    }
    
    # Retry wrapper for unreliable operations
    retry_operation() {
      local max_retries="$1"
      local delay="$2"
      shift 2
      local operation=("$@")
      
      local attempt=1
      while [ "$attempt" -le "$max_retries" ]; do
        log_debug "Attempt $attempt/$max_retries: ''${operation[*]}"
        
        if "''${operation[@]}"; then
          log_debug "Operation succeeded on attempt $attempt"
          return 0
        fi
        
        local exit_code=$?
        log_warn "Attempt $attempt failed with code $exit_code"
        
        if [ "$attempt" -lt "$max_retries" ]; then
          log "Retrying in ''${delay}s..."
          sleep "$delay"
        fi
        
        attempt=$((attempt + 1))
      done
      
      log_error "Operation failed after $max_retries attempts"
      return 1
    }
    
    # Graceful degradation wrapper
    try_with_fallback() {
      local primary_cmd=("$1")
      local fallback_cmd=("$2")
      local operation_name="$3"
      
      log_debug "Trying primary: ''${primary_cmd[*]}"
      
      if ''${primary_cmd[@]} 2>&1 | while read -r line; do log_debug "$line"; done; then
        log_debug "Primary command succeeded"
        return 0
      fi
      
      log_warn "Primary command failed, trying fallback: ''${fallback_cmd[*]}"
      
      if ''${fallback_cmd[@]} 2>&1 | while read -r line; do log_debug "$line"; done; then
        log "Fallback command succeeded for: $operation_name"
        return 0
      fi
      
      log_error "Both primary and fallback commands failed for: $operation_name"
      handle_error 5 "$operation_name" "All methods failed"
      return 1
    }
    
    # Check dependencies and report missing ones
    check_dependencies() {
      local missing=()
      local optional_missing=()
      
      # Required dependencies
      local required_deps=("jq" "date" "mktemp" "mkdir")
      for dep in "''${required_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
          missing+=("$dep")
        fi
      done
      
      # Optional dependencies
      local optional_deps=("zenity" "kdialog" "notify-send" "xdg-open")
      for dep in "''${optional_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
          optional_missing+=("$dep")
        fi
      done
      
      # Report missing dependencies
      if [ ''${#missing[@]} -gt 0 ]; then
        log_critical "Missing required dependencies: ''${missing[*]}"
        return 1
      fi
      
      if [ ''${#optional_missing[@]} -gt 0 ]; then
        log_warn "Missing optional dependencies (features may be limited): ''${optional_missing[*]}"
      fi
      
      return 0
    }
    
    # System health check
    check_system_health() {
      local warnings=()
      
      # Check disk space
      local output_dir="''${CHRONICLE_OUTPUT_DIR:-$HOME/.local/share/step-records}"
      local available_space=$(df -BM "$(dirname "$output_dir")" | awk 'NR==2 {print $4}' | sed 's/M//')
      
      if [ "$available_space" -lt 100 ]; then
        warnings+=("Low disk space: ''${available_space}MB available")
      fi
      
      # Check memory
      local available_mem=$(free -m | awk 'NR==2 {print $7}')
      if [ "$available_mem" -lt 500 ]; then
        warnings+=("Low memory: ''${available_mem}MB available")
      fi
      
      # Check CPU load
      local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
      local cpu_count=$(nproc)
      local load_threshold=$((cpu_count * 2))
      
      if [ "$(echo "$cpu_load > $load_threshold" | bc -l)" -eq 1 ]; then
        warnings+=("High CPU load: $cpu_load (threshold: $load_threshold)")
      fi
      
      # Report warnings
      if [ ''${#warnings[@]} -gt 0 ]; then
        log_warn "System health warnings:"
        for warning in "''${warnings[@]}"; do
          log_warn "  - $warning"
        done
        return 1
      fi
      
      log "System health check passed"
      return 0
    }
    
    # Performance monitoring
    monitor_performance() {
      local operation="$1"
      local start_time=$(date +%s%N)
      
      shift
      "$@"
      local exit_code=$?
      
      local end_time=$(date +%s%N)
      local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
      
      log_debug "Performance: $operation completed in ''${duration}ms"
      
      # Warn if operation took too long
      if [ "$duration" -gt 1000 ]; then
        log_warn "Slow operation: $operation took ''${duration}ms"
      fi
      
      return $exit_code
    }
  '';
}
