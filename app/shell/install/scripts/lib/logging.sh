#!/usr/bin/env bash

# Ensure colors are available
if [[ -z "$COLORS_IMPORTED" ]]; then
    source "$LIB_DIR/colors.sh"
fi

# Logging Configuration (nur wenn noch nicht definiert)
if [[ -z "${LOG_LEVEL_DEBUG:-}" ]]; then
    declare -g LOG_LEVEL_DEBUG=0
    declare -g LOG_LEVEL_INFO=1
    declare -g LOG_LEVEL_WARN=2
    declare -g LOG_LEVEL_ERROR=3
    
    # Default log level (can be overridden by environment)
    declare -g CURRENT_LOG_LEVEL=${INSTALL_DEBUG:-1}
fi

# Logging Functions
log_header() {
    echo -e "\n${BLUE}═══ $1 ═══${NC}\n"
}

log_debug() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] && 
        echo -e "${GRAY}[DEBUG]${NC} $*"
}

log_info() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]] && 
        echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARN ]] && 
        echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ]] && 
        echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_section() {
    echo -e "\n${BLUE}═══ $* ═══${NC}\n"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_failure() {
    echo -e "${RED}✗${NC} $*"
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

# Error exit helper
log_error_exit() {
    log_error "$1"
    exit 1
}

# Export all logging functions
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

for func in "${logging_functions[@]}"; do
    export -f "$func"
done

# Check script execution
check_script_execution "COLORS_IMPORTED" "log_info 'Logging system initialized'"