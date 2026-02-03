{ lib, pkgs }:

{
  # Logging functions
  log = message: ''echo "✅ [StepRecorder] ${message}"'';
  warn = message: ''echo "⚠️  [StepRecorder] ${message}"'';
  error = message: ''echo "❌ [StepRecorder] ${message}" >&2'';
  debug = message: ''
    if [ "$DEBUG_MODE" = "true" ]; then
      echo "🐛 [DEBUG] ${message}" >&2
    fi
  '';

  # Timestamp generation
  timestamp = ''date '+%Y%m%d_%H%M%S' '';
  isoTimestamp = ''date -u '+%Y-%m-%dT%H:%M:%SZ' '';

  # Path helpers
  expandPath = path: ''eval echo "${path}"'';
  
  # Session ID generation
  generateSessionId = ''echo "session_$(date '+%Y%m%d_%H%M%S')"'';

  # File existence check
  fileExists = path: ''[ -f "${path}" ]'';
  dirExists = path: ''[ -d "${path}" ]'';

  # Safe directory creation
  ensureDir = path: ''mkdir -p "${path}"'';

  # Get system info
  getHostname = ''hostname'';
  getUsername = ''whoami'';
  getNixosVersion = ''nixos-version 2>/dev/null || echo 'unknown' '';

  # Detect display server
  detectDisplayServer = ''
    session_type="''${XDG_SESSION_TYPE:-x11}"
    echo "$session_type"
  '';

  # Check if command exists
  commandExists = cmd: ''command -v ${cmd} &> /dev/null'';
}
