#!/usr/bin/env bash

# Import colors if not already imported
if [[ -z "$COLORS_IMPORTED" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi

# Logging levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# Default log level from environment or INFO
CURRENT_LOG_LEVEL=${INSTALL_DEBUG:-1}

# Logging functions
log_header() {
    echo -e "\n=== ${BLUE}$1${NC} ===\n"
}

log_debug() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] && echo -e "${GRAY}[DEBUG] $*${NC}"
}

log_info() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]] && echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARN ]] && echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ]] && echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Section logging
log_section() {
    echo -e "\n${BLUE}=== $* ===${NC}\n"
}

# Success/Failure logging
log_success() {
    echo -e "${GREEN}✓ $*${NC}"
}

log_failure() {
    echo -e "${RED}✗ $*${NC}"
}

# Status logging
log_status() {
    local status=$1
    shift
    if [[ $status -eq 0 ]]; then
        log_success "$*"
    else
        log_failure "$*"
    fi
}

# Export functions
export -f log_debug log_info log_warn log_error log_section log_success log_failure log_status