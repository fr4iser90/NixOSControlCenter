# checks/hardware/storage.sh — placeholder (was empty in git; TODO expand)
{ pkgs }:
pkgs.writeText "storage.sh" ''
  #!/usr/bin/env bash
  check_storage_info() {
    log_section "Detecting Storage" 2>/dev/null || true
    export STORAGE_PRIMARY="$(lsblk -dno NAME,SIZE,TYPE 2>/dev/null | head -1 || true)"
    log_info "Storage: ''${STORAGE_PRIMARY:-unknown}" 2>/dev/null || true
    return 0
  }
  export -f check_storage_info
''
