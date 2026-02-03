{ lib, pkgs }:

rec {
  # Check if window is allowed based on whitelist/blacklist
  isWindowAllowed = { whitelist, blacklist }: ''
    is_window_allowed() {
      local window_title="$1"
      local app_name="$2"

      debug "Checking window: title='$window_title' app='$app_name'"

      # Check blacklist first
      for blocked in ${lib.concatStringsSep " " blacklist}; do
        # Case-insensitive matching
        if [[ "''${window_title,,}" == *"''${blocked,,}"* ]] || [[ "''${app_name,,}" == *"''${blocked,,}"* ]]; then
          debug "BLOCKED by blacklist: $blocked"
          return 1
        fi
      done

      # Check whitelist (if not empty)
      ${if (lib.length whitelist) > 0 then ''
        local allowed=false
        for allowed_app in ${lib.concatStringsSep " " whitelist}; do
          # Case-insensitive matching
          if [[ "''${window_title,,}" == *"''${allowed_app,,}"* ]] || [[ "''${app_name,,}" == *"''${allowed_app,,}"* ]]; then
            allowed=true
            debug "ALLOWED by whitelist: $allowed_app"
            break
          fi
        done
        if [ "$allowed" != "true" ]; then
          debug "NOT in whitelist, rejecting"
          return 1
        fi
      '' else ''
        debug "No whitelist configured, allowing all"
      ''}

      debug "Window ALLOWED"
      return 0
    }
  '';

  # Redact sensitive text patterns
  redactSensitiveText = { patterns, enabled }: ''
    redact_sensitive_text() {
      local text="$1"
      local redacted="$text"

      ${if enabled then ''
        # Redact common sensitive patterns
        redacted=$(echo "$redacted" | sed -E 's/(password|secret|token|key)[[:space:]]*[:=][[:space:]]*[^[:space:]]+/***REDACTED***/gi')
        
        # Redact credit card numbers
        redacted=$(echo "$redacted" | sed -E 's/[0-9]{4}[- ][0-9]{4}[- ][0-9]{4}[- ][0-9]{4}/****-****-****-****/g')
        
        # Redact custom patterns
        ${lib.concatMapStringsSep "\n" (pattern: ''
          redacted=$(echo "$redacted" | sed -E 's/${pattern}/***REDACTED***/gi')
        '') patterns}
      '' else ''
        # Privacy redaction disabled
        :
      ''}

      echo "$redacted"
    }
  '';

  # Generate privacy-aware step description
  generateStepDescription = { redactPasswords, sensitivePatterns }: ''
    generate_step_description() {
      local action="$1"
      local window_info="$2"
      local timestamp="$3"

      local window_title=$(echo "$window_info" | cut -d'|' -f1)
      local app_name=$(echo "$window_info" | cut -d'|' -f2)

      # Redact sensitive information
      window_title=$(redact_sensitive_text "$window_title")

      case "$action" in
        "click")
          echo "Clicked on '$window_title' ($app_name)"
          ;;
        "keypress")
          echo "Pressed keys in '$window_title' ($app_name)"
          ;;
        "window_change")
          echo "Switched to '$window_title' ($app_name)"
          ;;
        "manual")
          echo "Manual step captured at '$window_title' ($app_name)"
          ;;
        "initial")
          echo "Recording started at '$window_title' ($app_name)"
          ;;
        *)
          echo "Action performed in '$window_title' ($app_name)"
          ;;
      esac
    }
  '';
}
