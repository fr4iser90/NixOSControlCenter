#!/usr/bin/env bash

check_network() {
    log_section "Detecting Network Configuration"

    local primary_interface=""
    local hostname=""

    # Primäres Interface finden (das mit Default-Route)
    if command -v ip &> /dev/null; then
        primary_interface=$(ip route show default | grep -Po '(?<=dev )[^ ]+' | head -1)
    fi

    # Hostname
    hostname=$(hostname)

    # Ausgabe
    log_info "Network Configuration:"
    log_info "  Hostname: ${hostname}"
    log_info "  Primary Interface: ${primary_interface}"

    # Export für weitere Verarbeitung
    export SYSTEM_HOSTNAME="$hostname"
    export SYSTEM_PRIMARY_INTERFACE="$primary_interface"
    
    return 0
}

# Export functions
export -f check_network