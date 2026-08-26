#!/usr/bin/env bash
# HARD GATE — install-wizard staged systemConfig must match module options.nix types.
#
# Runs apply_install_template for key presets, loads leaves via config-loader,
# then nix-evaluates lib.evalModules against discovered options (SSOT = options.nix).
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NIXOS="$ROOT/nixos"
MM_LIB="$NIXOS/core/management/module-manager/lib"

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

FAIL=0

echo "=== validate-systemconfig-writes (options.nix SSOT) ==="

if [[ -z "${SCRIPT_ROOT:-}" || ! -f "${SCRIPT_ROOT}/lib/dry-run.sh" ]]; then
  PKG_ERR="$(mktemp)"
  if ! SCRIPT_ROOT="$(nix-build --no-out-link -E "
    let
      pkgs = import <nixpkgs> { };
      lib = pkgs.lib;
      helpers = import $MM_LIB/module-config.nix {
        inherit lib;
        systemConfig = { };
      };
      inherit (helpers) getModuleApi getModuleMetadata;
    in
      (import $NIXOS/core/management/install-wizard/scripts {
        inherit pkgs getModuleApi getModuleMetadata;
      }).scriptTree
  " 2>"$PKG_ERR")"; then
    fail "could not build install-wizard scriptTree"
    sed -n '1,20p' "$PKG_ERR" | sed 's/^/    /'
    rm -f "$PKG_ERR"
    exit 1
  fi
  rm -f "$PKG_ERR"
fi
SHELL_SCRIPTS="$SCRIPT_ROOT"
export SCRIPT_ROOT SHELL_SCRIPTS ROOT

INSTALL_BASES_DIR="$SHELL_SCRIPTS/setup/modes/install-bases"
HOST_BLUEPRINTS_DIR="$SHELL_SCRIPTS/setup/modes/host-blueprints"

log_debug() { :; }
log_info() { :; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERR] $*" >&2; }
log_section() { :; }
log_success() { :; }
log_failure() { :; }
export -f log_debug log_info log_warn log_error log_section log_success log_failure

# shellcheck source=/dev/null
source "$SHELL_SCRIPTS/lib/dry-run.sh"
# shellcheck source=/dev/null
source "$SHELL_SCRIPTS/setup/config/apply-install-template.sh"
# shellcheck source=/dev/null
source "$SHELL_SCRIPTS/setup/config/config-paths.sh"
# shellcheck source=/dev/null
source "$SHELL_SCRIPTS/setup/config/config-facade.sh"
# shellcheck source=/dev/null
source "$SHELL_SCRIPTS/setup/config/config-writer.sh"

validate_staged_configs() {
  local label="$1"
  local configs_dir="$2"
  if [[ ! -d "$configs_dir" ]]; then
    fail "$label — missing $configs_dir"
    return 1
  fi
  local staging
  staging="$(dirname "$configs_dir")"
  local err out
  err="$(mktemp)"
  out="$(mktemp)"
  if ! nix-instantiate --eval --strict --json \
    --arg pkgs 'import <nixpkgs> {}' \
    --argstr repoRoot "$ROOT" \
    --argstr stagedRoot "$staging" \
    "$ROOT/tests/lib/validate-staged-systemconfig.nix" >"$out" 2>"$err"; then
    fail "$label — options check eval failed"
    sed 's/^/    /' "$err"
    rm -f "$err" "$out"
    return 1
  fi
  if jq -e '.ok != true' "$out" >/dev/null 2>&1; then
    fail "$label — systemConfig violates options.nix"
    jq -r '.errors[]?' "$out" 2>/dev/null | sed 's/^/    /'
    rm -f "$err" "$out"
    return 1
  fi
  local checked skipped
  checked="$(jq -r '.checked | join(", ")' "$out" 2>/dev/null || echo "?")"
  skipped="$(jq -r '.skipped | if length == 0 then empty else join(", ") end' "$out" 2>/dev/null || true)"
  pass "$label — options.nix types OK (checked: $checked)"
  if [[ -n "$skipped" ]]; then
    echo "    note: skipped options import for: $skipped"
  fi
  rm -f "$err" "$out"
}

apply_and_validate() {
  local label="$1"
  local profile="$2"
  local run_tmp
  run_tmp="$(mktemp -d)"
  export NIXOS_ROOT="$run_tmp/nixos"
  export CONFIGS_BASE="$NIXOS_ROOT/systemConfig"
  export MONOLITH_FILE="$NIXOS_ROOT/systemConfig.nix"
  export SYSTEM_CONFIG_FILE="$NIXOS_ROOT/system-config.nix"
  export NIXOS_CONFIG_DIR="$NIXOS"
  export NCC_LAYOUT=split
  export NCC_DRY_RUN=0
  mkdir -p "$NIXOS_ROOT"

  # shellcheck source=/dev/null
  source "$SHELL_SCRIPTS/setup/config/config-paths.sh"

  if [[ "$CONFIGS_BASE" != "$NIXOS_ROOT/systemConfig" ]]; then
    fail "$label — CONFIGS_BASE must stay under temp staging (got $CONFIGS_BASE)"
    rm -rf "$run_tmp"
    return
  fi

  backup_file() { return 0; }
  clean_old_configs() { return 0; }
  deploy_config() { return 0; }
  export -f backup_file clean_old_configs deploy_config

  if ! apply_install_template "$profile" >/dev/null 2>&1; then
    fail "$label — apply_install_template failed"
    rm -rf "$run_tmp"
    return
  fi

  if [[ ! -f "${CONFIGS_BASE}/core/management/system-manager/config.nix" ]]; then
    fail "$label — system-manager leaf missing after apply"
    rm -rf "$run_tmp"
    return
  fi

  validate_staged_configs "$label" "$CONFIGS_BASE"
  rm -rf "$run_tmp"
}

echo "== preset / blueprint writes vs module options =="
apply_and_validate "Desktop preset" "$INSTALL_BASES_DIR/desktop.nix"
apply_and_validate "Server preset" "$INSTALL_BASES_DIR/server.nix"
apply_and_validate "Jetson blueprint" "$HOST_BLUEPRINTS_DIR/fr4iser-jetson-orin"
apply_and_validate "fr4iser-home blueprint" "$HOST_BLUEPRINTS_DIR/fr4iser-home"

echo "=== validate-systemconfig-writes summary ==="
if [[ "$FAIL" -ne 0 ]]; then
  echo "FAILED — staged systemConfig violates module options.nix (fix config-writer / presets)."
  exit 1
fi
echo "OK — wizard writes match options.nix for checked presets."
exit 0
