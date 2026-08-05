#!/usr/bin/env bash
# Tests: preset/profile parsers + package writes + dry-run apply paths.
# Run: bash shell/scripts/tests/test-presets-dry-run.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SHELL_SCRIPTS="${ROOT}/shell/scripts"
PRESETS_DIR="${SHELL_SCRIPTS}/setup/modes/presets"
PROFILES_DIR="${SHELL_SCRIPTS}/setup/modes/profiles"
PACKAGE_SETS_DIR="${ROOT}/nixos/core/base/packages/components/sets"
PACKAGE_PRESETS_DIR="${ROOT}/nixos/core/base/packages/components/presets"

PASS=0
FAIL=0
ERRORS=()

pass() { PASS=$((PASS + 1)); echo "  PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); ERRORS+=("$*"); echo "  FAIL: $*"; }

assert_eq() {
    local label="$1" got="$2" want="$3"
    if [[ "$got" == "$want" ]]; then
        pass "$label"
    else
        fail "$label (got='$got' want='$want')"
    fi
}

assert_contains() {
    local label="$1" haystack="$2" needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$label"
    else
        fail "$label (missing '$needle' in: ${haystack:0:200})"
    fi
}

assert_not_contains() {
    local label="$1" haystack="$2" needle="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        pass "$label"
    else
        fail "$label (unexpected '$needle')"
    fi
}

# Minimal log stubs (before sourcing writers)
log_debug() { :; }
log_info() { :; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERR] $*" >&2; }
log_section() { :; }
log_success() { :; }
log_failure() { :; }
export -f log_debug log_info log_warn log_error log_section log_success log_failure

# shellcheck source=/dev/null
source "${SHELL_SCRIPTS}/lib/dry-run.sh"
# shellcheck source=/dev/null
source "${SHELL_SCRIPTS}/setup/config/setup-preset-profile.sh"

# ---------- Unit: parsers ----------
echo "== Parser: desktop.nix =="
DESKTOP="${PRESETS_DIR}/desktop.nix"
assert_eq "desktop systemType" "$(parse_nix_value "$DESKTOP" "systemType")" "desktop"
assert_eq "desktop packages empty" "$(parse_package_modules "$DESKTOP")" ""
assert_eq "desktop env" "$(parse_desktop_env "$DESKTOP")" "plasma"
assert_eq "desktop locale" "$(parse_locales_first "$DESKTOP")" "en_US.UTF-8"
assert_eq "desktop keyboard" "$(parse_nix_value "$DESKTOP" "keyboardLayout")" "de"
assert_eq "desktop timezone" "$(parse_nix_value "$DESKTOP" "timeZone")" "Europe/Berlin"
assert_eq "desktop hostName null" "$(parse_nix_value "$DESKTOP" "hostName")" "null"

echo "== Parser: server.nix =="
SERVER="${PRESETS_DIR}/server.nix"
assert_eq "server systemType" "$(parse_nix_value "$SERVER" "systemType")" "server"
assert_eq "server packages empty" "$(parse_package_modules "$SERVER")" ""
assert_eq "server env empty" "$(parse_desktop_env "$SERVER")" ""

echo "== Parser: fr4iser-jetson (Jetson Nano) =="
JETSON="${PROFILES_DIR}/fr4iser-jetson"
assert_eq "jetson systemType" "$(parse_nix_value "$JETSON" "systemType")" "desktop"
assert_eq "jetson packages" "$(parse_package_modules "$JETSON")" "streaming emulation game-dev web-dev"
assert_eq "jetson env" "$(parse_desktop_env "$JETSON")" "plasma"

echo "== Parser: fr4iser-home =="
HOME_P="${PROFILES_DIR}/fr4iser-home"
assert_eq "home packages" "$(parse_package_modules "$HOME_P")" "gaming streaming emulation game-dev web-dev"
assert_eq "home env" "$(parse_desktop_env "$HOME_P")" "plasma"

echo "== Parser: regression (empty + comments must not become modules) =="
REG=$(mktemp --suffix=.nix)
cat > "$REG" <<'EOF'
{
  systemType = "server";
  packageModules = [];
  # evil comment that old parser ate
  "not-a-module"
  desktop = {
    enable = false;
    environment = null;
  };
  timeZone = "Europe/Berlin";
  locales = [ "en_US.UTF-8" ];
  keyboardLayout = "us";
}
EOF
assert_eq "regression empty modules" "$(parse_package_modules "$REG")" ""
assert_eq "regression systemType same-line" "$(parse_nix_value "$REG" "systemType")" "server"
rm -f "$REG"

REG2=$(mktemp --suffix=.nix)
cat > "$REG2" <<'EOF'
{
  packageModules = [
    "docker"
    # skip me
    "database"
    "web-server"
  ];
}
EOF
assert_eq "multiline modules ignore comments" "$(parse_package_modules "$REG2")" "docker database web-server"
rm -f "$REG2"

# ---------- write_packages_config (temp split layout) ----------
echo "== write_packages_config: Homelab defaults =="
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export NIXOS_ROOT="$TMP/nixos"
export NIXOS_CONFIG_DIR="${ROOT}/nixos"
export SERIALIZE_NIX="${ROOT}/nixos/core/management/system-manager/lib/serialize-json-to-nix.nix"
export NCC_LAYOUT=split
export NCC_DRY_RUN=0
mkdir -p "$NIXOS_ROOT"

# Re-source paths/writer with temp root
# shellcheck source=/dev/null
source "${SHELL_SCRIPTS}/setup/config/config-paths.sh"
# shellcheck source=/dev/null
source "${SHELL_SCRIPTS}/setup/config/config-facade.sh"
# shellcheck source=/dev/null
source "${SHELL_SCRIPTS}/setup/config/config-writer.sh"
# shellcheck source=/dev/null
source "${SHELL_SCRIPTS}/ui/gui/gui-lib.sh"

write_packages_config docker database web-server
PKG_FILE="${CONFIGS_BASE}/core/base/packages/config.nix"
[[ -f "$PKG_FILE" ]] || fail "packages config missing at $PKG_FILE"
PKG_CONTENT=$(cat "$PKG_FILE")
assert_contains "homelab has docker" "$PKG_CONTENT" '"docker"'
assert_contains "homelab has database" "$PKG_CONTENT" '"database"'
assert_contains "homelab has web-server" "$PKG_CONTENT" '"web-server"'
assert_not_contains "no bogus preset= string" "$PKG_CONTENT" 'preset ='
# Count quoted modules
MOD_COUNT=$(echo "$PKG_CONTENT" | grep -oE '"[^"]+"' | grep -cvE '^(systemPackages|userPackages)$' || true)
# packageModules quotes only (3 modules)
PM=$(echo "$PKG_CONTENT" | awk '/packageModules/,/\]/' | grep -oE '"[^"]+"' | tr -d '"' | tr '\n' ' ' | sed 's/[[:space:]]*$//')
assert_eq "homelab packageModules order" "$PM" "docker database web-server"

echo "== write_packages_config: empty =="
write_packages_config
PKG_CONTENT=$(cat "$PKG_FILE")
assert_contains "empty packageModules" "$PKG_CONTENT" 'packageModules = [];'
assert_not_contains "empty has no module names" "$PKG_CONTENT" '"docker"'

echo "== GUI answers → PACKAGE_MODULES =="
ANSWERS=$(mktemp)
export NCC_GUI_ANSWERS_FILE="$ANSWERS"
printf "PACKAGE_MODULES=%s\n" "'streaming emulation'" > "$ANSWERS"
ncc_apply_gui_package_modules
PKG_CONTENT=$(cat "$PKG_FILE")
PM=$(echo "$PKG_CONTENT" | awk '/packageModules/,/\]/' | grep -oE '"[^"]+"' | tr -d '"' | tr '\n' ' ' | sed 's/[[:space:]]*$//')
assert_eq "gui PACKAGE_MODULES" "$PM" "streaming emulation"

printf "PACKAGE_MODULES=%s\n" "''" > "$ANSWERS"
ncc_apply_gui_package_modules
PKG_CONTENT=$(cat "$PKG_FILE")
assert_contains "gui empty clears modules" "$PKG_CONTENT" 'packageModules = [];'
rm -f "$ANSWERS"
unset NCC_GUI_ANSWERS_FILE

# ---------- PRESET_DEFAULT_PACKAGES SSOT ----------
echo "== PRESET_DEFAULT_PACKAGES =="
# shellcheck source=/dev/null
source "${SHELL_SCRIPTS}/ui/prompts/setup-options.sh"
assert_eq "Desktop defaults" "${PRESET_DEFAULT_PACKAGES[Desktop]:-}" ""
assert_eq "Server defaults" "${PRESET_DEFAULT_PACKAGES[Server]:-}" ""
assert_eq "Homelab defaults" "${PRESET_DEFAULT_PACKAGES[Homelab Server]:-}" "docker database web-server"
assert_eq "From Scratch defaults" "${PRESET_DEFAULT_PACKAGES[From Scratch]:-}" ""
assert_eq "Jetson defaults" "${PRESET_DEFAULT_PACKAGES[Jetson Nano]:-}" ""

# ---------- Feature modules exist as package sets ----------
echo "== ALL_FEATURES package sets exist =="
SKIP_DE="plasma gnome xfce"
for feat in "${ALL_FEATURES[@]}"; do
    if [[ " $SKIP_DE " == *" $feat "* ]]; then
        continue
    fi
    if [[ -f "${PACKAGE_SETS_DIR}/${feat}.nix" ]]; then
        pass "set exists: $feat"
    else
        fail "missing package set for feature: $feat"
    fi
done

# ---------- Package component presets parse ----------
echo "== packages/components/presets/*.nix =="
for pf in "${PACKAGE_PRESETS_DIR}"/*.nix; do
    [[ -f "$pf" ]] || continue
    name=$(basename "$pf" .nix)
    mods=$(nix-instantiate --eval --strict -E "let p = import $pf; in builtins.concatStringsSep \" \" p.modules" 2>/dev/null | tr -d '"')
    if [[ -n "$mods" ]]; then
        pass "preset $name → $mods"
        for m in $mods; do
            if [[ -f "${PACKAGE_SETS_DIR}/${m}.nix" ]]; then
                pass "  $name contains set $m"
            else
                fail "  $name references missing set $m"
            fi
        done
    else
        fail "preset $name has no modules"
    fi
done

# ---------- Full setup_predefined_profile (temp + dry-run deploy) ----------
echo "== setup_predefined_profile dry writes =="
apply_and_check() {
    local label="$1" profile="$2" want_type="$3" want_pkgs="$4" want_env="$5"
    local run_tmp
    run_tmp=$(mktemp -d)
    export NIXOS_ROOT="$run_tmp/nixos"
    export SYSTEM_CONFIG_FILE="$NIXOS_ROOT/system-config.nix"
    export NCC_LAYOUT=split
    export NCC_DRY_RUN=0
    mkdir -p "$NIXOS_ROOT"
    # refresh path exports
    # shellcheck source=/dev/null
    source "${SHELL_SCRIPTS}/setup/config/config-paths.sh"

    backup_file() { return 0; }
    clean_old_configs() { return 0; }
    deploy_config() { return 0; }
    export -f backup_file clean_old_configs deploy_config

    if ! setup_predefined_profile "$profile" >/dev/null 2>&1; then
        fail "$label setup_predefined_profile failed"
        rm -rf "$run_tmp"
        return
    fi

    local sm pkg desk
    sm=$(cat "${CONFIGS_BASE}/core/management/system-manager/config.nix" 2>/dev/null || echo "")
    pkg=$(cat "${CONFIGS_BASE}/core/base/packages/config.nix" 2>/dev/null || echo "")
    desk=$(cat "${CONFIGS_BASE}/core/base/desktop/config.nix" 2>/dev/null || echo "")

    assert_contains "$label systemType" "$sm" "systemType = \"$want_type\""

    if [[ -z "$want_pkgs" ]]; then
        assert_contains "$label empty packages" "$pkg" 'packageModules = [];'
        assert_not_contains "$label no garbage modules" "$pkg" '"#" '
    else
        local got
        got=$(echo "$pkg" | awk '/packageModules/,/\]/' | grep -oE '"[^"]+"' | tr -d '"' | tr '\n' ' ' | sed 's/[[:space:]]*$//')
        assert_eq "$label packages" "$got" "$want_pkgs"
    fi

    if [[ -n "$want_env" ]]; then
        assert_contains "$label desktop env" "$desk" "environment = \"$want_env\""
    else
        # disabled desktop
        if echo "$desk" | grep -q 'enable = false'; then
            pass "$label desktop disabled"
        else
            fail "$label expected desktop disabled"
        fi
    fi

    # localization not scrambled
    local loc
    loc=$(cat "${CONFIGS_BASE}/core/base/localization/config.nix" 2>/dev/null || echo "")
    assert_contains "$label locale" "$loc" 'en_US.UTF-8'
    assert_not_contains "$label loc not comment" "$loc" 'Will be set'

    rm -rf "$run_tmp"
}

apply_and_check "Desktop preset" "$DESKTOP" "desktop" "" "plasma"
apply_and_check "Server preset" "$SERVER" "server" "" ""
apply_and_check "Jetson profile" "$JETSON" "desktop" "streaming emulation game-dev web-dev" "plasma"
apply_and_check "fr4iser-home" "$HOME_P" "desktop" "gaming streaming emulation game-dev web-dev" "plasma"

# ---------- Dry-run mode (no files under /etc, validates nix fragments) ----------
echo "== NCC_DRY_RUN=1 write_packages_config =="
export NCC_DRY_RUN=1
export NIXOS_ROOT="/etc/nixos-SHOULD-NOT-TOUCH-$$"
# shellcheck source=/dev/null
source "${SHELL_SCRIPTS}/setup/config/config-paths.sh"
# Capture dry-run previews (log_info is stubbed silent above)
log_info() { echo "$*"; }
export -f log_info
OUT=$(write_packages_config docker database web-server 2>&1) || true
log_info() { :; }
export -f log_info
if [[ -d "$NIXOS_ROOT" ]]; then
    fail "dry-run created $NIXOS_ROOT"
    rm -rf "$NIXOS_ROOT"
else
    pass "dry-run did not create fake /etc root"
fi
assert_contains "dry-run logs skip" "$OUT" "DRY-RUN"
assert_contains "dry-run preview docker" "$OUT" '"docker"'
assert_contains "dry-run preview database" "$OUT" '"database"'
assert_contains "dry-run preview web-server" "$OUT" '"web-server"'
assert_not_contains "dry-run no preset=" "$OUT" 'preset ='
export NCC_DRY_RUN=0

# ---------- Summary ----------
echo
echo "========================================"
echo "Results: $PASS passed, $FAIL failed"
echo "========================================"
if [[ $FAIL -gt 0 ]]; then
    echo "Failures:"
    for e in "${ERRORS[@]}"; do echo "  - $e"; done
    exit 1
fi
exit 0
