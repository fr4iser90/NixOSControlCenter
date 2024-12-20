#!/usr/bin/env bash
set -euo pipefail

# Source core components
source "$CORE_DIR/imports.sh"

format_option() {
    local option="$1"
    local is_selected="${2:-false}"
    
    # Format based on option type
    case "$option" in
        "Desktop"|"Server"|"HomelabServer")
            # Main categories in cyan
            log_formatted "${CYAN}${option}${NC}"
            ;;
        *)
            # Other options in default color
            log_formatted "$option"
            ;;
    esac
}

format_selected_option() {
    local option="$1"
    log_success "Selected: $option"
}

format_header() {
    local text="$1"
    log_header "$text"
}

format_section() {
    local text="$1"
    log_section "$text"
}

# Check script execution
check_script_execution "CORE_DIR" "format_option"