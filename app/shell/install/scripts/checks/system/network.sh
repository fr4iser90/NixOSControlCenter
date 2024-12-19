#!/usr/bin/env bash

log_section "Detecting Network Configuration"

get_network_info() {
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
    log_info "  Hostname: ${CYAN}${hostname}${NC}"
    log_info "  Primary Interface: ${CYAN}${primary_interface}${NC}"

    # Export für weitere Verarbeitung
    export SYSTEM_HOSTNAME="$hostname"
    export SYSTEM_PRIMARY_INTERFACE="$primary_interface"
}

# Ausführen
get_network_info