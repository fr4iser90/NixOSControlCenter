# Logging helpers — palette + badge tone from getModuleApi "cli-formatter".
# Dynamic messages must printf colors on ONE line (do not splice ui.messages.* into
# `fn() { …; }` — trailing newlines break bash).
{ pkgs, getModuleApi ? null, ... }:
assert getModuleApi != null;
let
  ui = getModuleApi "cli-formatter";
  c = ui.colors;
in
pkgs.writeText "logging.sh" ''
#!/usr/bin/env bash

# Ensure colors are available (cli-formatter palette via colors.sh)
if [[ -z "''${COLORS_IMPORTED:-}" ]]; then
    source "$LIB_DIR/colors.sh"
fi

# Logging Configuration (nur wenn noch nicht definiert)
if [[ -z "''${LOG_LEVEL_DEBUG:-}" ]]; then
    declare -g LOG_LEVEL_DEBUG=0
    declare -g LOG_LEVEL_INFO=1
    declare -g LOG_LEVEL_WARN=2
    declare -g LOG_LEVEL_ERROR=3
    declare -g CURRENT_LOG_LEVEL=''${INSTALL_DEBUG:-1}
fi

# Honor NCC_CLI_NESTED=1 — parent owns header / dry banner / Next
log_header() {
    if [[ -n "''${NCC_CLI_NESTED:-}" ]]; then
        return 0
    fi
    printf '%b\n' "\n${c.blue}=== $1 ===${c.reset}\n"
}

log_debug() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] && \
        printf '%b\n' "${c.dim}[DEBUG]${c.reset} $*"
}

log_info() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]] && \
        printf '%b\n' "${c.blue}[INFO]${c.reset} $*"
}

log_warn() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARN ]] && \
        printf '%b\n' "${c.yellow}[WARN]${c.reset} $*" >&2
}

log_error() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ]] && \
        printf '%b\n' "${c.red}[ERROR]${c.reset} $*" >&2
}

log_section() {
    printf '%b\n' "\n${c.cyan}=== $* ===${c.reset}\n"
}

log_success() {
    printf '%b\n' "${c.green}[ OK ]${c.reset} $*"
}

log_failure() {
    printf '%b\n' "${c.red}[ERROR]${c.reset} $*"
}

log_loading() {
    printf '%b\n' "${c.cyan}$*${c.reset}"
}

# Next hint — skipped when nested (parent owns skeleton)
log_next() {
    if [[ -n "''${NCC_CLI_NESTED:-}" ]]; then
        return 0
    fi
    printf '%b\n' "${c.blue}Next: $*${c.reset}"
}

log_status() {
    local status=$1
    shift
    if [[ $status -eq 0 ]]; then
        log_success "$*"
    else
        log_failure "$*"
    fi
}

log_error_exit() {
    log_error "$1"
    exit 1
}

declare -a logging_functions=(
    "log_header"
    "log_debug"
    "log_info"
    "log_warn"
    "log_error"
    "log_section"
    "log_success"
    "log_failure"
    "log_loading"
    "log_next"
    "log_status"
    "log_error_exit"
)

for func in "''${logging_functions[@]}"; do
    export -f "$func"
done

check_script_execution "COLORS_IMPORTED" "log_info 'Logging system initialized'"
''
