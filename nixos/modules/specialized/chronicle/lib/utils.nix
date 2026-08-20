{ lib, pkgs, getModuleApi }:

let
  ui = getModuleApi "cli-formatter";
  c = ui.colors;
in
{
  # Dynamic log helpers — must use colors + printf on ONE line (messages.* end
  # with a newline and break `fn() { ${ui.messages…}; }` → `; }` syntax errors).
  shellHelpers = ''
    log() { printf '%b\n' "${c.green}[StepRecorder] $*${c.reset}"; }
    warn() { printf '%b\n' "${c.yellow}[StepRecorder] $*${c.reset}"; }
    error() { printf '%b\n' "${c.red}[StepRecorder] $*${c.reset}" >&2; }
    debug() {
      if [ "''${DEBUG_MODE:-false}" = "true" ]; then
        printf '%b\n' "${c.dim}[DEBUG] $*${c.reset}" >&2
      fi
    }
  '';

  # One-shot helpers (fixed Nix-time message text — OK as full statements)
  log = message: ''${ui.messages.success "[StepRecorder] ${message}"}'';
  warn = message: ''${ui.messages.warning "[StepRecorder] ${message}"}'';
  error = message: ''${ui.messages.error "[StepRecorder] ${message}"}'';
  debug = message: ''
    if [ "''${DEBUG_MODE:-false}" = "true" ]; then
      ${ui.messages.detailLevel "DEBUG" "${message}"}
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
