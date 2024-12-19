#!/usr/bin/env bash

log_section "Checking User Configuration"

get_user_info() {
    local current_user
    local current_shell
    local is_admin

    # Basis-Informationen
    current_user=$(whoami)
    current_shell=$(getent passwd "$current_user" | cut -d: -f7)
    
    # Admin-Status (wheel Gruppe)
    if groups "$current_user" | grep -q "wheel"; then
        is_admin="true"
    else
        is_admin="false"
    fi

    # Ausgabe
    log_info "User Configuration:"
    log_info "  Username: ${CYAN}${current_user}${NC}"
    log_info "  Shell: ${CYAN}${current_shell}${NC}"
    log_info "  Admin: ${CYAN}${is_admin}${NC}"

    # Export für weitere Verarbeitung
    export CURRENT_USER="$current_user"
    export CURRENT_SHELL="$current_shell"
    export IS_ADMIN="$is_admin"
}

# Ausführen
get_user_info