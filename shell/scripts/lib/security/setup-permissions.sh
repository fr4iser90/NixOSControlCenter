#!/usr/bin/env bash

setup_permissions() {
    log_section "Setting up script permissions"
    
    # Setze Berechtigungen für alle .sh Dateien
    if ! find "$SCRIPT_ROOT" -type f -name "*.sh" -exec chmod +x {} \; ; then
        log_error "Failed to set execute permissions"
        return 1
    fi
    
    log_success "Execute permissions set for all shell scripts ✓"
    return 0
}

# Export function
export -f setup_permissions

# Check script execution
check_script_execution "SCRIPT_ROOT" "setup_permissions"