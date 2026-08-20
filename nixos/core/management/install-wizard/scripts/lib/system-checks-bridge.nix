# Installer bridge → system-manager prebuild checks (SSOT).
# NO second CPU/GPU detection — only call prebuild-check-*.
{ pkgs }:
pkgs.writeText "system-checks-bridge.sh" ''
#!/usr/bin/env bash
# SSOT: nixos/core/management/system-manager/components/system-checks/prebuild/checks/

_ncc_run_prebuild() {
  local bin="$1"
  if command -v "$bin" >/dev/null 2>&1; then
    if declare -F log_info >/dev/null 2>&1; then
      log_info "Using system-checks SSOT: $bin"
    fi
    "$bin" || true
    return 0
  fi
  if declare -F log_warn >/dev/null 2>&1; then
    log_warn "$bin not on PATH — enable system-manager system-checks (no duplicate detect in installer)"
  fi
  return 0
}

_ncc_read_hw_field() {
  local key="$1"
  local f
  for f in \
    "''${CONFIGS_BASE:-}/core/base/hardware/config.nix" \
    "''${SYSTEM_CONFIG_DIR:-/etc/nixos}/systemConfig/core/base/hardware/config.nix"
  do
    if [[ -f "$f" ]]; then
      grep -E "^[[:space:]]*''${key}[[:space:]]*=" "$f" 2>/dev/null | head -1 \
        | sed -E 's/^[^=]+=[[:space:]]*"?//; s/"?;[[:space:]]*$//; s/;[[:space:]]*$//' \
        | tr -d '"'
      return 0
    fi
  done
  echo ""
}

check_cpu_info() {
  if declare -F log_section >/dev/null 2>&1; then log_section "CPU (system-checks SSOT)"; fi
  _ncc_run_prebuild prebuild-check-cpu
  local v
  v="$(_ncc_read_hw_field cpu)"
  export CPU_VENDOR="''${v:-''${CPU_VENDOR:-none}}"
  export CPU_VIRTUALIZATION="''${CPU_VIRTUALIZATION:-none}"
  return 0
}

check_gpu_info() {
  if declare -F log_section >/dev/null 2>&1; then log_section "GPU (system-checks SSOT)"; fi
  _ncc_run_prebuild prebuild-check-gpu
  local v
  v="$(_ncc_read_hw_field gpu)"
  export GPU_CONFIG="''${v:-''${GPU_CONFIG:-none}}"
  return 0
}

export -f _ncc_run_prebuild _ncc_read_hw_field check_cpu_info check_gpu_info
''
