# Device-target discovery + match — thin bash over ui/gui/device_discover.py
# SSOT: host-blueprints/*/deviceTarget { enable = true; … }
{ pkgs, getModuleApi ? null, ... }:
pkgs.writeText "device-targets.sh" ''
  #!/usr/bin/env bash
  # Discover DEVICE_TARGETS from blueprints; match live hardware.
  # Override match: NCC_FORCE_DEVICE_TARGETS="Label A,Label B"

  _ncc_device_discover_py() {
    local cand
    for cand in \
      "''${SCRIPT_ROOT:-}/ui/gui/device_discover.py" \
      "''${UI_DIR:-}/gui/device_discover.py" \
      "$(cd "$(dirname "''${BASH_SOURCE[0]}")/../../ui/gui" 2>/dev/null && pwd)/device_discover.py"
    do
      [[ -n "$cand" && -f "$cand" ]] && { printf '%s\n' "$cand"; return 0; }
    done
    return 1
  }

  load_discovered_device_targets() {
    local py
    py="$(_ncc_device_discover_py)" || {
      DEVICE_TARGETS=()
      declare -g -A DEVICE_BLUEPRINT_MAP=()
      return 0
    }
    # shellcheck disable=SC1090
    eval "$(python3 "$py" export-bash)"
  }

  detect_install_device_targets() {
    local py
    py="$(_ncc_device_discover_py)" || return 0
    python3 "$py" match
  }

  export -f load_discovered_device_targets
  export -f detect_install_device_targets
''
