#!/usr/bin/env bash
# Full installer coverage: collect → presets/homelab/custom → deploy copy.
# Run: bash shell/scripts/tests/test-installer-full.sh
# Or:  bash shell/scripts/tests/run-all.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SHELL_SCRIPTS="${ROOT}/shell/scripts"

PASS=0
FAIL=0
ERRORS=()

pass() { PASS=$((PASS + 1)); echo "  PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); ERRORS+=("$*"); echo "  FAIL: $*"; }

assert_eq() {
    local label="$1" got="$2" want="$3"
    if [[ "$got" == "$want" ]]; then pass "$label"; else fail "$label (got='$got' want='$want')"; fi
}
assert_contains() {
    local label="$1" haystack="$2" needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then pass "$label"; else fail "$label (missing '$needle')"; fi
}
assert_file() {
    local label="$1" path="$2"
    if [[ -f "$path" ]]; then pass "$label"; else fail "$label (missing $path)"; fi
}
assert_dir() {
    local label="$1" path="$2"
    if [[ -d "$path" ]]; then pass "$label"; else fail "$label (missing $path)"; fi
}
pkg_modules() {
    local f="$1"
    [[ -f "$f" ]] || { echo ""; return; }
    echo "$(awk '/packageModules/,/\]/' "$f" | grep -oE '"[^"]+"' | tr -d '"' | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
}

# --- log stubs ---
log_debug() { :; }
log_info() { :; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERR] $*" >&2; }
log_section() { :; }
log_success() { :; }
log_failure() { :; }
log_header() { :; }
export -f log_debug log_info log_warn log_error log_section log_success log_failure log_header

# --- env bootstrap (mirrors env-paths.nix) ---
export INSTALL_ROOT="$ROOT"
export NIXOS_CONFIG_DIR="$ROOT/nixos"
export SCRIPT_ROOT="$SHELL_SCRIPTS"
export CORE_DIR="$SCRIPT_ROOT/core"
export LIB_DIR="$SCRIPT_ROOT/lib"
export UI_DIR="$SCRIPT_ROOT/ui"
export SETUP_DIR="$SCRIPT_ROOT/setup"
export CHECKS_DIR="$SCRIPT_ROOT/checks"
export PROMPTS_DIR="$UI_DIR/prompts"
export MODES_DIR="$SETUP_DIR/modes"
export MODES_HOMELAB_DIR="$MODES_DIR/homelab"
export CONFIG_DIR="$SETUP_DIR/config"
export SERIALIZE_NIX="$ROOT/nixos/core/management/system-manager/lib/serialize-json-to-nix.nix"
export NCC_LAYOUT=split
export NCC_DRY_RUN=0
export NCC_INSTALL_UI=tui
export NCC_DEPLOY_SKIP_PERMS=1
export NCC_DEPLOY_SKIP_REBUILD=1
export NCC_DEPLOY_NONINTERACTIVE=1

# shellcheck source=/dev/null
source "$LIB_DIR/colors.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/dry-run.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/utils.sh"
# shellcheck source=/dev/null
source "$SETUP_DIR/config/setup-preset-profile.sh"
# shellcheck source=/dev/null
source "$UI_DIR/gui/gui-lib.sh"
# shellcheck source=/dev/null
source "$PROMPTS_DIR/setup-options.sh"
# shellcheck source=/dev/null
# Strip auto-main so sourcing never invokes deploy_config
_DEP_TMP=$(mktemp)
awk '/check_script_execution/{next} {print}' "$CORE_DIR/deploy-build.sh" > "$_DEP_TMP"
source "$_DEP_TMP"
rm -f "$_DEP_TMP"
_REAL_DEPLOY_CONFIG="$(declare -f deploy_config)"
_REAL_DEPLOY_BASE="$(declare -f deploy_base_config)"
restore_deploy() {
    eval "$_REAL_DEPLOY_CONFIG"
    eval "$_REAL_DEPLOY_BASE"
    export -f deploy_config deploy_base_config
}
stub_deploy() {
    deploy_config() { return 0; }
    export -f deploy_config
}
# Homelab
# shellcheck source=/dev/null
source "$MODES_DIR/homelab/setup.sh"
# shellcheck source=/dev/null
source "$MODES_DIR/homelab/extensions/setup-homelab-config.sh"
# Load custom mode functions without hardware-config side effects / main guard
_CUSTOM_TMP=$(mktemp)
awk '
  /^if \[\[ -n "\$\{CHECKS_DIR/ { skip=1; next }
  skip && /^fi$/ { skip=0; next }
  skip { next }
  /check_script_execution/ { next }
  { print }
' "$MODES_DIR/custom/setup.sh" > "$_CUSTOM_TMP"
# shellcheck source=/dev/null
source "$_CUSTOM_TMP"
rm -f "$_CUSTOM_TMP"

# collect_system_data (strip auto-main guard — requires SYSTEM_CONFIG_FILE)
_COLLECT_TMP=$(mktemp)
awk '/check_script_execution/{next} {print}' \
  "$SETUP_DIR/config/data-collection/collect-system-data.sh" > "$_COLLECT_TMP"
# shellcheck source=/dev/null
source "$_COLLECT_TMP"
rm -f "$_COLLECT_TMP"

# init helpers (dispatch only)
get_predefined_profile_file() {
    local profile_name="$1"
    local profile_file=""
    case "$profile_name" in
        "Fr4iser Personal Desktop") profile_file="fr4iser-home" ;;
        "Fr4iser Jetson Nano") profile_file="fr4iser-jetson" ;;
        *) return 1 ;;
    esac
    local profile_path="$SETUP_DIR/modes/profiles/$profile_file"
    [[ -f "$profile_path" ]] || return 1
    echo "$profile_path"
}
export -f get_predefined_profile_file

# ---------- fresh sandbox (must NOT run in $() — exports must stick) ----------
new_sandbox() {
    local sb
    sb=$(mktemp -d)
    export HOME="$sb/home"
    mkdir -p "$HOME"
    export NIXOS_ROOT="$sb/etc/nixos"
    export SYSTEM_CONFIG_DIR="$NIXOS_ROOT"
    export SYSTEM_CONFIG_FILE="$NIXOS_ROOT/system-config.nix"
    export MONOLITH_FILE="$NIXOS_ROOT/systemConfig.nix"
    export CONFIGS_BASE="$NIXOS_ROOT/systemConfig"
    export NCC_DEPLOY_STAGING_DIR="$sb/staging"
    export NCC_GUI_ANSWERS_FILE="$sb/answers"
    : > "$NCC_GUI_ANSWERS_FILE"
    mkdir -p "$NIXOS_ROOT"
    # shellcheck source=/dev/null
    source "$SETUP_DIR/config/config-paths.sh"
    # shellcheck source=/dev/null
    source "$SETUP_DIR/config/config-facade.sh"
    # shellcheck source=/dev/null
    source "$SETUP_DIR/config/config-writer.sh"
    SANDBOX_ROOT="$sb"
}

write_answers() {
    local file="$1"; shift
    : > "$file"
    local kv
    for kv in "$@"; do
        local k="${kv%%=*}"
        local v="${kv#*=}"
        printf '%s=%q\n' "$k" "$v" >> "$file"
    done
}

stub_checks() {
    check_hardware_config() { return 0; }
    check_cpu_info() { CPU_VENDOR=amd; return 0; }
    check_gpu_info() { GPU_CONFIG=none; return 0; }
    check_locale() {
        SYSTEM_LOCALE=en_US.UTF-8
        SYSTEM_KEYBOARD_LAYOUT=us
        SYSTEM_TIMEZONE=Europe/Berlin
        return 0
    }
    check_users() {
        ALL_USERS='    "testuser" = {
      role = "admin";
      defaultShell = "bash";
      autoLogin = false;
    };'
        return 0
    }
    check_bootloader() { BOOT_TYPE=systemd-boot; return 0; }
    check_hosting() { return 0; }
    backup_file() { return 0; }
    clean_old_configs() { return 0; }
    export -f check_hardware_config check_cpu_info check_gpu_info check_locale \
        check_users check_bootloader check_hosting backup_file clean_old_configs
}

# ============================================================================
# 1) collect_system_data baseline
# ============================================================================
echo "== collect_system_data =="
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
export SYSTEM_TYPE=desktop HOSTNAME=testhost
if ! collect_system_data >/tmp/ncc-collect-out.txt 2>/tmp/ncc-collect-err.txt; then
    fail "collect_system_data failed: $(head -c 500 /tmp/ncc-collect-err.txt)"
else
    pass "collect_system_data ran"
fi
assert_file "baseline system-manager" "$CONFIGS_BASE/core/management/system-manager/config.nix"
assert_file "baseline packages" "$CONFIGS_BASE/core/base/packages/config.nix"
assert_file "baseline desktop" "$CONFIGS_BASE/core/base/desktop/config.nix"
assert_file "baseline hardware" "$CONFIGS_BASE/core/base/hardware/config.nix"
assert_file "baseline localization" "$CONFIGS_BASE/core/base/localization/config.nix"
assert_file "baseline network" "$CONFIGS_BASE/core/base/network/config.nix"
assert_file "baseline user" "$CONFIGS_BASE/core/base/user/config.nix"
assert_file "baseline overrides" "$CONFIGS_BASE/core/base/overrides/config.nix"
assert_file "baseline logging" "$CONFIGS_BASE/core/base/logging/config.nix"
assert_contains "baseline systemType desktop" "$(cat "$CONFIGS_BASE/core/management/system-manager/config.nix")" 'systemType = "desktop"'
assert_eq "baseline empty packages" "$(pkg_modules "$CONFIGS_BASE/core/base/packages/config.nix")" ""
rm -rf "$SB"

# ============================================================================
# 2) Desktop / Server / Jetson via setup_predefined_profile + real deploy_base_config
# ============================================================================
run_preset_with_deploy() {
    local label="$1" profile="$2" want_type="$3" want_pkgs="$4" want_env="$5"
    local sb
    new_sandbox; sb="$SANDBOX_ROOT"
    stub_checks
    # seed machine overlays that must survive deploy
    echo '{ /* hardware */ }' > "$SYSTEM_CONFIG_DIR/hardware-configuration.nix"
    echo 'lock-marker' > "$SYSTEM_CONFIG_DIR/flake.lock"
    mkdir -p "$SYSTEM_CONFIG_DIR/secrets/passwords/keepme"
    echo 'secret' > "$SYSTEM_CONFIG_DIR/secrets/passwords/keepme/.hashedPassword"

    # Tiny fake repo source (avoid copying entire nixos tree — still exercise deploy path)
    local fake_src
    fake_src=$(mktemp -d)
    echo '{ description = "test flake"; }' > "$fake_src/flake.nix"
    echo 'repo-core' > "$fake_src/marker-from-repo"
    mkdir -p "$fake_src/core"
    echo 'core-file' > "$fake_src/core/x"
    export NIXOS_CONFIG_DIR="$fake_src"

    DEPLOYED=0
    # use real deploy_base_config; wrap deploy_config completion only
    setup_predefined_profile "$profile" >/dev/null 2>&1 || {
        fail "$label setup_predefined_profile"
        rm -rf "$sb" "$fake_src"
        return
    }

    assert_contains "$label systemType" "$(cat "$CONFIGS_BASE/core/management/system-manager/config.nix")" "systemType = \"$want_type\""
    if [[ -z "$want_pkgs" ]]; then
        assert_contains "$label empty pkgs" "$(cat "$CONFIGS_BASE/core/base/packages/config.nix")" 'packageModules = [];'
    else
        assert_eq "$label packages" "$(pkg_modules "$CONFIGS_BASE/core/base/packages/config.nix")" "$want_pkgs"
    fi
    if [[ -n "$want_env" ]]; then
        assert_contains "$label DE" "$(cat "$CONFIGS_BASE/core/base/desktop/config.nix")" "environment = \"$want_env\""
    else
        assert_contains "$label DE off" "$(cat "$CONFIGS_BASE/core/base/desktop/config.nix")" 'enable = false'
    fi

    # Deploy assertions
    assert_file "$label deploy preserved hardware" "$SYSTEM_CONFIG_DIR/hardware-configuration.nix"
    assert_file "$label deploy preserved flake.lock" "$SYSTEM_CONFIG_DIR/flake.lock"
    assert_file "$label deploy preserved secrets" "$SYSTEM_CONFIG_DIR/secrets/passwords/keepme/.hashedPassword"
    assert_file "$label deploy copied repo marker" "$SYSTEM_CONFIG_DIR/marker-from-repo"
    assert_file "$label deploy copied flake.nix" "$SYSTEM_CONFIG_DIR/flake.nix"
    assert_file "$label deploy kept written packages" "$CONFIGS_BASE/core/base/packages/config.nix"
    if [[ -z "$want_pkgs" ]]; then
        assert_contains "$label packages survive deploy" "$(cat "$CONFIGS_BASE/core/base/packages/config.nix")" 'packageModules = [];'
    else
        assert_eq "$label packages survive deploy" "$(pkg_modules "$CONFIGS_BASE/core/base/packages/config.nix")" "$want_pkgs"
    fi
    # staging cleaned
    if [[ -d "$NCC_DEPLOY_STAGING_DIR" ]]; then
        fail "$label staging not cleaned"
    else
        pass "$label staging cleaned"
    fi

    rm -rf "$sb" "$fake_src"
    export NIXOS_CONFIG_DIR="$ROOT/nixos"
}

echo "== Presets + deploy copy =="
run_preset_with_deploy "Desktop" "$SETUP_DIR/modes/presets/desktop.nix" "desktop" "" "plasma"
run_preset_with_deploy "Server" "$SETUP_DIR/modes/presets/server.nix" "server" "" ""
run_preset_with_deploy "Jetson" "$SETUP_DIR/modes/profiles/fr4iser-jetson" "desktop" "streaming emulation game-dev web-dev" "plasma"

# ============================================================================
# 3) Homelab single (GUI answers)
# ============================================================================
echo "== Homelab single =="
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
write_answers "$NCC_GUI_ANSWERS_FILE" \
    "ADMIN_USER=hladmin" \
    "HOMELAB_TYPE=single" \
    "USE_EXTRA_USER=no" \
    "EMAIL=admin@example.com" \
    "DOMAIN=example.com" \
    "ENABLE_DESKTOP=true" \
    "PACKAGE_MODULES=docker database web-server"

# Avoid real deploy here — stub to isolate config writes
stub_deploy

setup_homelab >/dev/null 2>&1 || fail "homelab single setup_homelab failed"

assert_contains "hl single systemType" "$(cat "$CONFIGS_BASE/core/management/system-manager/config.nix")" 'systemType = "server"'
assert_eq "hl single packages" "$(pkg_modules "$CONFIGS_BASE/core/base/packages/config.nix")" "docker database web-server"
assert_contains "hl single admin user" "$(cat "$CONFIGS_BASE/core/base/user/config.nix")" '"hladmin"'
assert_contains "hl single desktop" "$(cat "$CONFIGS_BASE/core/base/desktop/config.nix")" 'environment = "plasma"'
assert_file "hl single homelab cfg" "$CONFIGS_BASE/modules/infrastructure/homelab-manager/config.nix"
assert_contains "hl single type" "$(cat "$CONFIGS_BASE/modules/infrastructure/homelab-manager/config.nix")" 'homelab.type = "single"'
assert_contains "hl email" "$(cat "$CONFIGS_BASE/core/base/localization/config.nix")" 'admin@example.com'
assert_contains "hl domain" "$(cat "$CONFIGS_BASE/core/base/localization/config.nix")" 'example.com'
rm -rf "$SB"

# ============================================================================
# 4) Homelab swarm + virt user + password file
# ============================================================================
echo "== Homelab swarm + password =="
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
write_answers "$NCC_GUI_ANSWERS_FILE" \
    "ADMIN_USER=hladmin" \
    "HOMELAB_TYPE=swarm" \
    "SWARM_ROLE=worker" \
    "VIRT_USER=docker" \
    "VIRT_PASSWORD=TestPass123!" \
    "EMAIL=admin@example.com" \
    "DOMAIN=lab.example.com" \
    "ENABLE_DESKTOP=false"

stub_deploy

if command -v mkpasswd >/dev/null 2>&1; then
    setup_homelab >/dev/null 2>&1 || fail "homelab swarm setup failed"
    assert_contains "hl swarm type" "$(cat "$CONFIGS_BASE/modules/infrastructure/homelab-manager/config.nix")" 'homelab.type = "swarm"'
    assert_contains "hl swarm role worker" "$(cat "$CONFIGS_BASE/modules/infrastructure/homelab-manager/config.nix")" 'homelab.role = "worker"'
    assert_contains "hl swarm virt user" "$(cat "$CONFIGS_BASE/core/base/user/config.nix")" '"docker"'
    assert_contains "hl swarm desktop off" "$(cat "$CONFIGS_BASE/core/base/desktop/config.nix")" 'enable = false'
    assert_file "hl password hash" "$SYSTEM_CONFIG_DIR/secrets/passwords/docker/.hashedPassword"
    if [[ -s "$SYSTEM_CONFIG_DIR/secrets/passwords/docker/.hashedPassword" ]]; then
        pass "hl password hash non-empty"
    else
        fail "hl password hash empty"
    fi
else
    fail "mkpasswd missing — skip swarm password asserts"
fi
rm -rf "$SB"

# ============================================================================
# 5) From Scratch / setup_custom
# ============================================================================
echo "== From Scratch (setup_custom) =="
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
# baseline required for custom (only updates desktop/packages)
export SYSTEM_TYPE=desktop
collect_system_data >/dev/null 2>&1 || true
stub_deploy
write_answers "$NCC_GUI_ANSWERS_FILE" "USE_EXTRA_USER=no"

setup_custom desktop plasma web-dev docker >/dev/null 2>&1 || fail "setup_custom failed"
assert_contains "custom plasma" "$(cat "$CONFIGS_BASE/core/base/desktop/config.nix")" 'environment = "plasma"'
assert_eq "custom packages" "$(pkg_modules "$CONFIGS_BASE/core/base/packages/config.nix")" "web-dev docker"
rm -rf "$SB"

new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
export SYSTEM_TYPE=server
collect_system_data >/dev/null 2>&1 || true
stub_deploy
setup_custom server docker database >/dev/null 2>&1 || fail "setup_custom server failed"
assert_eq "custom server packages" "$(pkg_modules "$CONFIGS_BASE/core/base/packages/config.nix")" "docker database"
rm -rf "$SB"

# ============================================================================
# 6) init.sh dispatch (stubbed select + checks)
# ============================================================================
echo "== init.sh dispatch =="
restore_deploy
dispatch_selection() {
    local selection="$1"
    local selected_modules_raw="$selection"
    if [[ "$selected_modules_raw" =~ ^LOAD_PROFILE: ]]; then
        setup_predefined_profile "${selected_modules_raw#LOAD_PROFILE:}" || return 1
    elif [[ "$selected_modules_raw" == "Desktop" ]]; then
        setup_predefined_profile "$SETUP_DIR/modes/presets/desktop.nix" || return 1
    elif [[ "$selected_modules_raw" == "Server" ]]; then
        setup_predefined_profile "$SETUP_DIR/modes/presets/server.nix" || return 1
    elif [[ "$selected_modules_raw" == "Homelab Server" ]]; then
        setup_homelab || return 1
    elif [[ "$selected_modules_raw" == "Jetson Nano" ]]; then
        setup_predefined_profile "$SETUP_DIR/modes/profiles/fr4iser-jetson" || return 1
    elif [[ "$selected_modules_raw" =~ ^IMPORT_CONFIG: ]]; then
        local config_path="${selected_modules_raw#IMPORT_CONFIG:}"
        if ncc_dry_run; then
            ncc_dry_skip "import config" "$config_path"
            return 0
        fi
        cp "$config_path" "$SYSTEM_CONFIG_FILE" || return 1
        deploy_config || return 1
    else
        IFS=' ' read -ra selected_modules <<< "$selected_modules_raw"
        if [[ "${selected_modules[0]}" =~ ^(desktop|server)$ ]]; then
            setup_custom "${selected_modules[@]}" || return 1
        else
            return 1
        fi
    fi
}

for sel in "Desktop" "Server" "Jetson Nano"; do
    new_sandbox; SB="$SANDBOX_ROOT"
    stub_checks
    # tiny deploy source
    fake_src=$(mktemp -d)
    echo 'f' > "$fake_src/flake.nix"
    export NIXOS_CONFIG_DIR="$fake_src"
    if dispatch_selection "$sel" >/dev/null 2>&1; then
        pass "dispatch $sel"
        assert_file "dispatch $sel wrote system-manager" "$CONFIGS_BASE/core/management/system-manager/config.nix"
        assert_file "dispatch $sel deployed flake" "$SYSTEM_CONFIG_DIR/flake.nix"
    else
        fail "dispatch $sel"
    fi
    rm -rf "$SB" "$fake_src"
    export NIXOS_CONFIG_DIR="$ROOT/nixos"
done

# From Scratch via dispatch
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
stub_deploy
collect_system_data >/dev/null 2>&1 || true
if dispatch_selection "desktop gnome python-dev" >/dev/null 2>&1; then
    pass "dispatch From Scratch"
    assert_contains "dispatch gnome" "$(cat "$CONFIGS_BASE/core/base/desktop/config.nix")" 'environment = "gnome"'
    assert_eq "dispatch python-dev" "$(pkg_modules "$CONFIGS_BASE/core/base/packages/config.nix")" "python-dev"
else
    fail "dispatch From Scratch"
fi
rm -rf "$SB"

# Homelab via dispatch
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
write_answers "$NCC_GUI_ANSWERS_FILE" \
    "ADMIN_USER=u1" "HOMELAB_TYPE=single" "USE_EXTRA_USER=no" \
    "EMAIL=a@b.co" "DOMAIN=b.co" "ENABLE_DESKTOP=false"
stub_deploy
if dispatch_selection "Homelab Server" >/dev/null 2>&1; then
    pass "dispatch Homelab Server"
    assert_eq "dispatch hl packages" "$(pkg_modules "$CONFIGS_BASE/core/base/packages/config.nix")" "docker database web-server"
else
    fail "dispatch Homelab Server"
fi
rm -rf "$SB"

# LOAD_PROFILE
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
fake_src=$(mktemp -d); echo 'f' > "$fake_src/flake.nix"; export NIXOS_CONFIG_DIR="$fake_src"
if dispatch_selection "LOAD_PROFILE:$SETUP_DIR/modes/profiles/fr4iser-home" >/dev/null 2>&1; then
    pass "dispatch LOAD_PROFILE"
    assert_eq "LOAD_PROFILE packages" "$(pkg_modules "$CONFIGS_BASE/core/base/packages/config.nix")" "gaming streaming emulation game-dev web-dev"
else
    fail "dispatch LOAD_PROFILE"
fi
rm -rf "$SB" "$fake_src"
export NIXOS_CONFIG_DIR="$ROOT/nixos"

# IMPORT_CONFIG dry-run
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
IMP=$(mktemp)
echo '{ systemType = "desktop"; }' > "$IMP"
export NCC_DRY_RUN=1
log_info() { echo "$*"; }; export -f log_info
OUT=$(dispatch_selection "IMPORT_CONFIG:$IMP" 2>&1) || true
log_info() { :; }; export -f log_info
assert_contains "IMPORT dry-run skip" "$OUT" "DRY-RUN"
[[ ! -f "$SYSTEM_CONFIG_FILE" ]] && pass "IMPORT dry-run no copy" || fail "IMPORT dry-run wrote file"
export NCC_DRY_RUN=0
rm -rf "$SB" "$IMP"

# ============================================================================
# 7) Dry-run gates: writers + deploy + password
# ============================================================================
echo "== Dry-run gates =="
restore_deploy
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
export NCC_DRY_RUN=1
log_info() { echo "$*"; }; export -f log_info
OUT=$(write_packages_config docker 2>&1)
assert_contains "dry write packages" "$OUT" "DRY-RUN"
[[ ! -e "$CONFIGS_BASE/core/base/packages/config.nix" ]] && pass "dry no packages file" || fail "dry wrote packages"
OUT=$(deploy_config 2>&1)
assert_contains "dry deploy" "$OUT" "DRY-RUN"
virt_user=docker virt_password=secret OUT=$(create_password_file 2>&1)
assert_contains "dry password" "$OUT" "DRY-RUN"
[[ ! -e "$SYSTEM_CONFIG_DIR/secrets/passwords/docker/.hashedPassword" ]] && pass "dry no password file" || fail "dry wrote password"
log_info() { :; }; export -f log_info
export NCC_DRY_RUN=0
rm -rf "$SB"

# ============================================================================
# 8) GUI package override on Desktop (+ browsers, keep detected hardware)
# ============================================================================
echo "== GUI PACKAGE_MODULES override =="
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
export CPU_VENDOR=intel GPU_CONFIG=qxl-virtual MEMORY_GB=8
write_answers "$NCC_GUI_ANSWERS_FILE" \
    "PACKAGE_MODULES=gaming" \
    "BROWSERS=firefox brave chromium" \
    "ADMIN_USER=guiuser"
stub_deploy
setup_predefined_profile "$SETUP_DIR/modes/presets/desktop.nix" >/dev/null 2>&1 || fail "gui override setup"
assert_eq "gui override packages" "$(pkg_modules "$CONFIGS_BASE/core/base/packages/config.nix")" "gaming"
PKG_ALL=$(cat "$CONFIGS_BASE/core/base/packages/config.nix")
assert_contains "gui browsers brave" "$PKG_ALL" '"brave"'
assert_contains "gui browsers chromium" "$PKG_ALL" '"chromium"'
assert_contains "gui browsers firefox" "$PKG_ALL" '"firefox"'
HW=$(cat "$CONFIGS_BASE/core/base/hardware/config.nix")
assert_contains "gui keep cpu detection" "$HW" 'cpu = "intel"'
assert_contains "gui keep gpu detection" "$HW" 'gpu = "qxl-virtual"'
assert_contains "gui admin user" "$(cat "$CONFIGS_BASE/core/base/user/config.nix")" '"guiuser"'
rm -rf "$SB"

# ============================================================================
# 8b) Answers path survives $(select_setup_mode)-style subshell
# ============================================================================
echo "== NCC_GUI_ANSWERS_FILE parent ownership =="
new_sandbox; SB="$SANDBOX_ROOT"
ncc_gui_ensure_answers_file
PARENT_ANS="$NCC_GUI_ANSWERS_FILE"
(
    # simulate command-substitution child
    ncc_gui_ensure_answers_file
    [[ "$NCC_GUI_ANSWERS_FILE" == "$PARENT_ANS" ]] || exit 1
    write_answers "$NCC_GUI_ANSWERS_FILE" "PACKAGE_MODULES=gaming" "BROWSERS=firefox"
)
[[ "$NCC_GUI_ANSWERS_FILE" == "$PARENT_ANS" ]] && pass "parent answers path stable" || fail "parent answers path lost"
got=$(ncc_gui_answer PACKAGE_MODULES) || fail "parent cannot read child-written answers"
assert_eq "parent reads PACKAGE_MODULES" "$got" "gaming"
rm -rf "$SB"

# ============================================================================
echo
echo "========================================"
echo "Full installer: $PASS passed, $FAIL failed"
echo "========================================"
if [[ $FAIL -gt 0 ]]; then
    echo "Failures:"
    for e in "${ERRORS[@]}"; do echo "  - $e"; done
    exit 1
fi
exit 0
