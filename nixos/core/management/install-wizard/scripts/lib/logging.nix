# Logging helpers — colors from cli-formatter via colors.sh; badge tone matches ui.badges.
{ pkgs, getModuleApi ? null, ... }:
pkgs.writeText "logging.sh" ''
#!/usr/bin/env bash

# Ensure colors are available (cli-formatter palette)
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

log_header() {
    printf '%b\n' "\n''${BLUE}=== $1 ===''${NC}\n"
}

log_debug() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] && \
        printf '%b\n' "''${GRAY}[DEBUG]''${NC} $*"
}

log_info() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]] && \
        printf '%b\n' "''${BLUE}[INFO]''${NC} $*"
}

log_warn() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARN ]] && \
        printf '%b\n' "''${YELLOW}[WARN]''${NC} $*" >&2
}

log_error() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ]] && \
        printf '%b\n' "''${RED}[ERROR]''${NC} $*" >&2
}

log_section() {
    printf '%b\n' "\n''${CYAN}=== $* ===''${NC}\n"
}

log_success() {
    printf '%b\n' "''${GREEN}[ OK ]''${NC} $*"
}

log_failure() {
    printf '%b\n' "''${RED}[ERROR]''${NC} $*"
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
    "log_status"
    "log_error_exit"
)

for func in "''${logging_functions[@]}"; do
    export -f "$func"
done

check_script_execution "COLORS_IMPORTED" "log_info 'Logging system initialized'"
''
