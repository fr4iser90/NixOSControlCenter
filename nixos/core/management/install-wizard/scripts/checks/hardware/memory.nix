# checks/hardware/memory.sh — placeholder (was empty in git; TODO expand)
{ pkgs }:
pkgs.writeText "memory.sh" ''
  #!/usr/bin/env bash
  check_memory_info() {
    log_section "Detecting Memory" 2>/dev/null || true
    local kb
    kb="$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
    export MEMORY_TOTAL_GB="$((kb / 1024 / 1024))"
    log_info "Memory: ''${MEMORY_TOTAL_GB} GB" 2>/dev/null || true
    return 0
  }
  export -f check_memory_info
''
