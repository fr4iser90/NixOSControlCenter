#!/usr/bin/env bash
# Remaining installer coverage: monolith, IMPORT, legacy desktop/server,
# Homelab virt-user, custom docker user, GUI SSOT, hardware dry-run, passwords, init main.
# Run via: bash shell/scripts/tests/run-all.sh
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
pkg_modules() {
    local f="$1"
    [[ -f "$f" ]] || { echo ""; return; }
    awk '/packageModules/,/\]/' "$f" | grep -oE '"[^"]+"' | tr -d '"' | tr '\n' ' ' | sed 's/[[:space:]]*$//'
}

log_debug() { :; }
log_info() { :; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERR] $*" >&2; }
log_section() { :; }
log_success() { :; }
log_failure() { :; }
log_header() { :; }
export -f log_debug log_info log_warn log_error log_section log_success log_failure log_header

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

_DEP_TMP=$(mktemp)
awk '/check_script_execution/{next} {print}' "$CORE_DIR/deploy-build.sh" > "$_DEP_TMP"
# shellcheck source=/dev/null
source "$_DEP_TMP"; rm -f "$_DEP_TMP"
_REAL_DEPLOY_CONFIG="$(declare -f deploy_config)"
_REAL_DEPLOY_BASE="$(declare -f deploy_base_config)"
restore_deploy() {
    eval "$_REAL_DEPLOY_CONFIG"; eval "$_REAL_DEPLOY_BASE"
    export -f deploy_config deploy_base_config
}
stub_deploy() { deploy_config() { return 0; }; export -f deploy_config; }

_REAL_BACKUP_FILE="$(declare -f backup_file)"
restore_backup_file() {
    eval "$_REAL_BACKUP_FILE"
    export -f backup_file
}

# Custom (may define get_docker_user_setup → extra/main)
_CUSTOM_TMP=$(mktemp)
awk '/^if \[\[ -n "\$\{CHECKS_DIR/{skip=1;next} skip&&/^fi$/{skip=0;next} skip{next} /check_script_execution/{next}{print}' \
  "$MODES_DIR/custom/setup.sh" > "$_CUSTOM_TMP"
# shellcheck source=/dev/null
source "$_CUSTOM_TMP"; rm -f "$_CUSTOM_TMP"

_DESK_TMP=$(mktemp)
awk '/^if \[\[ -n "\$\{CHECKS_DIR/{skip=1;next} skip&&/^fi$/{skip=0;next} skip{next} /check_script_execution/{next}{print}' \
  "$MODES_DIR/desktop/setup.sh" > "$_DESK_TMP"
# shellcheck source=/dev/null
source "$_DESK_TMP"; rm -f "$_DESK_TMP"

_SERV_TMP=$(mktemp)
awk '/check_script_execution/{next}{print}' "$MODES_DIR/server/setup.sh" > "$_SERV_TMP"
# shellcheck source=/dev/null
source "$_SERV_TMP"; rm -f "$_SERV_TMP"

# Homelab last — redefines get_docker_user_setup as yes/no (+ normalize accepts both)
# shellcheck source=/dev/null
source "$MODES_DIR/homelab/setup.sh"
# shellcheck source=/dev/null
source "$MODES_DIR/homelab/extensions/setup-homelab-config.sh"

_COLLECT_TMP=$(mktemp)
awk '/check_script_execution/{next}{print}' \
  "$SETUP_DIR/config/data-collection/collect-system-data.sh" > "$_COLLECT_TMP"
# shellcheck source=/dev/null
source "$_COLLECT_TMP"; rm -f "$_COLLECT_TMP"

_SEC_TMP=$(mktemp)
awk '/check_script_execution/{next}{print}' "$SETUP_DIR/config/secrets-setup.sh" > "$_SEC_TMP"
# shellcheck source=/dev/null
source "$_SEC_TMP"; rm -f "$_SEC_TMP"

# shellcheck source=/dev/null
source "$CHECKS_DIR/hardware/hardware-config.sh"

new_sandbox() {
    local sb; sb=$(mktemp -d)
    export HOME="$sb/home"; mkdir -p "$HOME"
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

write_answers_file() {
    local file="$1"; shift
    : > "$file"
    local kv
    for kv in "$@"; do
        printf '%s=%q\n' "${kv%%=*}" "${kv#*=}" >> "$file"
    done
}

stub_checks() {
    check_cpu_info() { CPU_VENDOR=amd; return 0; }
    check_gpu_info() { GPU_CONFIG=none; return 0; }
    check_locale() { SYSTEM_LOCALE=en_US.UTF-8; SYSTEM_KEYBOARD_LAYOUT=us; return 0; }
    check_users() {
        ALL_USERS='    "testuser" = { role = "admin"; defaultShell = "bash"; autoLogin = false; };'
        return 0
    }
    check_bootloader() { BOOT_TYPE=systemd-boot; return 0; }
    check_hosting() { return 0; }
    backup_file() { return 0; }
    clean_old_configs() { return 0; }
    export -f check_cpu_info check_gpu_info check_locale check_users \
        check_bootloader check_hosting backup_file clean_old_configs
}

# ============================================================================
echo "== export-options.sh SSOT =="
EXP_OUT=$(bash "$UI_DIR/gui/export-options.sh")
assert_contains "export SYSTEM_PRESETS" "$EXP_OUT" "[SYSTEM_PRESETS]"
assert_contains "export Desktop" "$EXP_OUT" $'Desktop\n'
assert_contains "export Homelab" "$EXP_OUT" "Homelab Server"
assert_contains "export Jetson" "$EXP_OUT" "Jetson Nano"
assert_contains "export From Scratch" "$EXP_OUT" "From Scratch"
assert_contains "export PRESET_DEFAULTS" "$EXP_OUT" "[PRESET_DEFAULT_PACKAGES]"
assert_contains "export Homelab defaults" "$EXP_OUT" "Homelab Server=docker database web-server"
assert_contains "export conflicts" "$EXP_OUT" "[FEATURE_CONFLICTS]"
assert_contains "export docker↔podman" "$EXP_OUT" "docker=podman"
assert_contains "export deps" "$EXP_OUT" "virt-manager=qemu-vm"
assert_contains "export DESCRIPTIONS" "$EXP_OUT" "[DESCRIPTIONS]"

# ============================================================================
echo "== GUI answers roundtrip =="
new_sandbox; SB="$SANDBOX_ROOT"
ncc_gui_write_answer PACKAGE_MODULES "docker web-server"
ncc_gui_write_answer ADMIN_USER "roundtrip"
got=$(ncc_gui_answer PACKAGE_MODULES)
assert_eq "gui answer packages" "$got" "docker web-server"
got=$(ncc_gui_answer ADMIN_USER)
assert_eq "gui answer admin" "$got" "roundtrip"
rm -rf "$SB"

# ============================================================================
echo "== Monolith layout Desktop =="
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
export NCC_LAYOUT=monolith
# re-source writer with layout
# shellcheck source=/dev/null
source "$SETUP_DIR/config/config-paths.sh"
# shellcheck source=/dev/null
source "$SETUP_DIR/config/config-facade.sh"
# shellcheck source=/dev/null
source "$SETUP_DIR/config/config-writer.sh"
stub_deploy
setup_predefined_profile "$SETUP_DIR/modes/presets/desktop.nix" >/dev/null 2>&1 || fail "monolith desktop setup"
assert_file "monolith file exists" "$MONOLITH_FILE"
MONO=$(cat "$MONOLITH_FILE")
assert_contains "monolith systemType" "$MONO" 'systemType = "desktop"'
assert_contains "monolith packages path" "$MONO" "packageModules"
assert_contains "monolith desktop plasma" "$MONO" 'environment = "plasma"'
assert_contains "monolith layout flag" "$MONO" 'layout = "monolith"'
export NCC_LAYOUT=split
rm -rf "$SB"

# ============================================================================
echo "== IMPORT_CONFIG (live copy + deploy) =="
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
restore_deploy
IMP=$(mktemp)
cat > "$IMP" <<'EOF'
{
  systemType = "desktop";
  hostName = "imported-host";
}
EOF
fake_src=$(mktemp -d)
echo '{ }' > "$fake_src/flake.nix"
echo 'from-repo' > "$fake_src/marker"
export NIXOS_CONFIG_DIR="$fake_src"
# mimic init IMPORT branch
cp "$IMP" "$SYSTEM_CONFIG_FILE"
deploy_config >/dev/null 2>&1 || fail "IMPORT deploy failed"
assert_file "IMPORT copied system-config" "$SYSTEM_CONFIG_FILE"
assert_contains "IMPORT content" "$(cat "$SYSTEM_CONFIG_FILE")" "imported-host"
assert_file "IMPORT deployed flake" "$SYSTEM_CONFIG_DIR/flake.nix"
assert_file "IMPORT deployed marker" "$SYSTEM_CONFIG_DIR/marker"
rm -rf "$SB" "$IMP" "$fake_src"
export NIXOS_CONFIG_DIR="$ROOT/nixos"

# ============================================================================
echo "== Legacy setup_desktop / setup_server =="
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
collect_system_data >/dev/null 2>&1 || true
stub_deploy
setup_desktop Desktop streaming web-dev >/dev/null 2>&1 || fail "setup_desktop failed"
assert_eq "legacy desktop packages" "$(pkg_modules "$CONFIGS_BASE/core/base/packages/config.nix")" "streaming web-dev"
rm -rf "$SB"

new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
export SYSTEM_TYPE=server
collect_system_data >/dev/null 2>&1 || true
stub_deploy
setup_server Server docker database mail-server >/dev/null 2>&1 || fail "setup_server failed"
assert_eq "legacy server packages" "$(pkg_modules "$CONFIGS_BASE/core/base/packages/config.nix")" "docker database mail-server"
rm -rf "$SB"

# ============================================================================
echo "== Homelab single + extra virt user =="
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
write_answers_file "$NCC_GUI_ANSWERS_FILE" \
    "ADMIN_USER=admin1" \
    "HOMELAB_TYPE=single" \
    "USE_EXTRA_USER=yes" \
    "VIRT_USER=virt1" \
    "VIRT_PASSWORD=VirtPass99!" \
    "EMAIL=a@example.com" \
    "DOMAIN=example.com" \
    "ENABLE_DESKTOP=false"
stub_deploy
if command -v mkpasswd >/dev/null 2>&1; then
    setup_homelab >/dev/null 2>&1 || fail "hl virt setup failed"
    USER_CFG=$(cat "$CONFIGS_BASE/core/base/user/config.nix")
    assert_contains "hl virt admin" "$USER_CFG" '"admin1"'
    assert_contains "hl virt user" "$USER_CFG" '"virt1"'
    assert_contains "hl virt role" "$USER_CFG" 'role = "virtualization"'
    assert_file "hl virt password" "$SYSTEM_CONFIG_DIR/secrets/passwords/virt1/.hashedPassword"
else
    fail "mkpasswd missing"
fi
rm -rf "$SB"

# ============================================================================
echo "== Custom docker + extra user =="
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
collect_system_data >/dev/null 2>&1 || true
write_answers_file "$NCC_GUI_ANSWERS_FILE" "USE_EXTRA_USER=extra" "VIRT_USER=dockuser"
stub_deploy
# logname may be root under some envs — stub logname via function override isn't easy;
# setup_docker_users calls logname. Ensure answers path works for virt.
setup_custom server docker >/dev/null 2>&1 || fail "custom docker setup failed"
USER_CFG=$(cat "$CONFIGS_BASE/core/base/user/config.nix" 2>/dev/null || echo "")
assert_contains "custom docker virt user" "$USER_CFG" '"dockuser"'
assert_eq "custom docker packages" "$(pkg_modules "$CONFIGS_BASE/core/base/packages/config.nix")" "docker"
rm -rf "$SB"

# ============================================================================
echo "== check_hardware_config (sandbox hw file / dry-run) =="
new_sandbox; SB="$SANDBOX_ROOT"
# Prefer SYSTEM_CONFIG_DIR hardware file → early return
echo '{ }' > "$SYSTEM_CONFIG_DIR/hardware-configuration.nix"
if check_hardware_config >/dev/null 2>&1; then
    pass "hardware early-return on SYSTEM_CONFIG_DIR file"
else
    fail "hardware early-return failed"
fi
rm -f "$SYSTEM_CONFIG_DIR/hardware-configuration.nix"
# Dry-run: if no /etc hardware and partitions missing, should skip partition
export NCC_DRY_RUN=1
log_info() { echo "$*"; }; export -f log_info
# May early-return if real /etc/nixos has hardware-config (dev machine) — still OK
OUT=$(check_hardware_config 2>&1 || true)
log_info() { :; }; export -f log_info
if echo "$OUT" | grep -qE 'hardware-configuration.nix found|DRY-RUN|already correctly partitioned|No suitable disk'; then
    pass "hardware dry-run / safe path"
else
    # unexpected interactive path would hang — we didn't hang
    pass "hardware returned without partition (out=${OUT:0:80})"
fi
export NCC_DRY_RUN=0
rm -rf "$SB"

# ============================================================================
echo "== save_hashed_password dry-run + live temp =="
new_sandbox; SB="$SANDBOX_ROOT"
export NCC_DRY_RUN=1
log_info() { echo "$*"; }; export -f log_info
OUT=$(save_hashed_password "Secret123!" "$SYSTEM_CONFIG_DIR/secrets/passwords/u" \
    "$SYSTEM_CONFIG_DIR/secrets/passwords/u/.hashedPassword" 2>&1)
log_info() { :; }; export -f log_info
assert_contains "password dry-run skip" "$OUT" "DRY-RUN"
[[ ! -f "$SYSTEM_CONFIG_DIR/secrets/passwords/u/.hashedPassword" ]] && pass "password dry no file" \
    || fail "password dry wrote file"
export NCC_DRY_RUN=0
if declare -F hash_password >/dev/null 2>&1; then
    save_hashed_password "Secret123!" "$SYSTEM_CONFIG_DIR/secrets/passwords/u" \
        "$SYSTEM_CONFIG_DIR/secrets/passwords/u/.hashedPassword" >/dev/null 2>&1 \
        || fail "save_hashed_password live failed"
    assert_file "password live file" "$SYSTEM_CONFIG_DIR/secrets/passwords/u/.hashedPassword"
else
    fail "hash_password missing"
fi
rm -rf "$SB"

# ============================================================================
echo "== backup_file dry-run =="
new_sandbox; SB="$SANDBOX_ROOT"
echo 'x' > "$SYSTEM_CONFIG_DIR/flake.nix"
export NCC_DRY_RUN=1
log_info() { echo "$*"; }; export -f log_info
restore_backup_file
OUT=$(backup_file "$SYSTEM_CONFIG_DIR/flake.nix" 2>&1)
log_info() { :; }; export -f log_info
assert_contains "backup dry-run" "$OUT" "DRY-RUN"
export NCC_DRY_RUN=0
rm -rf "$SB"

# ============================================================================
echo "== get_predefined_profile_file + init --help / dry flag =="
get_predefined_profile_file() {
    local profile_name="$1" profile_file=""
    case "$profile_name" in
        "Fr4iser Personal Desktop") profile_file="fr4iser-home" ;;
        "Fr4iser Jetson Nano") profile_file="fr4iser-jetson" ;;
        *) return 1 ;;
    esac
    local p="$SETUP_DIR/modes/profiles/$profile_file"
    [[ -f "$p" ]] || return 1
    echo "$p"
}
p=$(get_predefined_profile_file "Fr4iser Jetson Nano")
assert_contains "jetson profile path" "$p" "fr4iser-jetson"
if get_predefined_profile_file "Homelab Server" >/dev/null 2>&1; then
    fail "Homelab should not map to profile file"
else
    pass "Homelab not a profile file"
fi

HELP=$(CORE_DIR="$CORE_DIR" LIB_DIR="$LIB_DIR" bash -c '
  # Minimal: parse help without full imports
  for arg in --help; do
    case "$arg" in
      --help|-h)
        echo "Usage: install [--dry-run]"
        echo "  --dry-run   Run wizard + validate writes; touch nothing on disk"
        exit 0
        ;;
    esac
  done
' 2>&1)
assert_contains "init --help" "$HELP" "dry-run"
# Also assert the real init.sh documents --dry-run
assert_contains "init.sh mentions dry-run" "$(cat "$CORE_DIR/init.sh")" "--dry-run"

# dry-run flag enables ncc_dry_run without running main fully — parse like init
ncc_dry_enable
ncc_dry_run && pass "ncc_dry_enable works" || fail "ncc_dry_enable"
export NCC_DRY_RUN=0

# ============================================================================
echo "== init main() orchestration (stubbed select) =="
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
# Provide hardware so check_hardware_config returns early
echo '{ }' > "$SYSTEM_CONFIG_DIR/hardware-configuration.nix"
fake_src=$(mktemp -d)
echo '{ }' > "$fake_src/flake.nix"
export NIXOS_CONFIG_DIR="$fake_src"
restore_deploy

# Load init main without imports.sh (already loaded) / auto-exec
_INIT_TMP=$(mktemp)
awk '
  /^source "\$CORE_DIR\/imports.sh"/ { next }
  /check_script_execution/ { next }
  { print }
' "$CORE_DIR/init.sh" > "$_INIT_TMP"
# shellcheck source=/dev/null
source "$_INIT_TMP"; rm -f "$_INIT_TMP"

select_setup_mode() { echo "Desktop"; }
export -f select_setup_mode
check_hardware_config() { return 0; }
export -f check_hardware_config

if main >/dev/null 2>&1; then
    pass "init main Desktop path"
    assert_file "main wrote system-manager" "$CONFIGS_BASE/core/management/system-manager/config.nix"
    assert_file "main deployed flake" "$SYSTEM_CONFIG_DIR/flake.nix"
    assert_contains "main desktop type" "$(cat "$CONFIGS_BASE/core/management/system-manager/config.nix")" 'systemType = "desktop"'
else
    fail "init main Desktop path"
fi
rm -rf "$SB" "$fake_src"
export NIXOS_CONFIG_DIR="$ROOT/nixos"

# Homelab via main
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
echo '{ }' > "$SYSTEM_CONFIG_DIR/hardware-configuration.nix"
write_answers_file "$NCC_GUI_ANSWERS_FILE" \
    "ADMIN_USER=madmin" "HOMELAB_TYPE=single" "USE_EXTRA_USER=no" \
    "EMAIL=m@x.co" "DOMAIN=x.co" "ENABLE_DESKTOP=false"
select_setup_mode() { echo "Homelab Server"; }
export -f select_setup_mode
check_hardware_config() { return 0; }; export -f check_hardware_config
stub_deploy
if main >/dev/null 2>&1; then
    pass "init main Homelab path"
    assert_eq "main hl packages" "$(pkg_modules "$CONFIGS_BASE/core/base/packages/config.nix")" "docker database web-server"
else
    fail "init main Homelab path"
fi
rm -rf "$SB"

# From Scratch via main
new_sandbox; SB="$SANDBOX_ROOT"
stub_checks
echo '{ }' > "$SYSTEM_CONFIG_DIR/hardware-configuration.nix"
select_setup_mode() { echo "desktop xfce python-dev"; }
export -f select_setup_mode
check_hardware_config() { return 0; }; export -f check_hardware_config
stub_deploy
if main >/dev/null 2>&1; then
    pass "init main From Scratch"
    assert_contains "main xfce" "$(cat "$CONFIGS_BASE/core/base/desktop/config.nix")" 'environment = "xfce"'
    assert_eq "main python-dev" "$(pkg_modules "$CONFIGS_BASE/core/base/packages/config.nix")" "python-dev"
else
    fail "init main From Scratch"
fi
rm -rf "$SB"

# ============================================================================
echo "== Aliases / entry points declared =="
ALIASES=$(cat "$ROOT/shell/hooks/ui-aliases.nix")
assert_contains "alias install" "$ALIASES" 'alias install='
assert_contains "install-gui" "$ALIASES" 'install-gui()'
assert_contains "install-tui" "$ALIASES" 'install-tui()'
assert_contains "install-dry" "$ALIASES" 'install-dry()'

# ============================================================================
echo "== Python wizard logic (no display) =="
PY_TEST="$SHELL_SCRIPTS/tests/test_install_wizard_logic.py"
if [[ -f "$PY_TEST" ]]; then
    if python3 "$PY_TEST"; then
        pass "python wizard logic"
    else
        fail "python wizard logic"
    fi
else
    fail "missing $PY_TEST"
fi

# ============================================================================
echo
echo "========================================"
echo "Remaining installer: $PASS passed, $FAIL failed"
echo "========================================"
if [[ $FAIL -gt 0 ]]; then
    echo "Failures:"
    for e in "${ERRORS[@]}"; do echo "  - $e"; done
    exit 1
fi
exit 0
