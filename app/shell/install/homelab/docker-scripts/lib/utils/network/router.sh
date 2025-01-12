#!/bin/bash

# Guard gegen mehrfaches Laden
if [ -n "${_ROUTER_UTILS_LOADED+x}" ]; then
    return 0
fi
_ROUTER_UTILS_LOADED=1

# Benötigte Funktionen laden
source "${DOCKER_LIB_DIR}/utils/format/output.sh"

# Debug Funktion
debug() {
    [[ "${DEBUG:-0}" == "1" ]] && echo "DEBUG: $*" >&2
}

find_router() {
    print_status "Detecting router..." "info"
    debug "Starting router detection"

    # Häufige Router-IPs
    local COMMON_GATEWAYS=(
        "192.168.0.1"    # Standard (TP-Link, D-Link)
        "192.168.1.1"    # Standard (Linksys, ASUS)
        "192.168.2.1"    # Alternative
        "192.168.178.1"  # Fritzbox
        "192.168.0.254"  # Manche Provider
        "10.0.0.1"       # Manche Netze
    )

    # Aktuelle Gateway-IP holen
    local CURRENT_GATEWAY
    CURRENT_GATEWAY=$(ip route | grep default | awk '{print $3}')
    debug "Found gateway: $CURRENT_GATEWAY"

    if [ -n "$CURRENT_GATEWAY" ]; then
        print_status "Found gateway: $CURRENT_GATEWAY" "info"

        # Prüfen ob erreichbar
        if ping -c 1 -W 1 "$CURRENT_GATEWAY" >/dev/null 2>&1; then
            print_status "Router is reachable" "success"

            # Browser öffnen
            if command -v xdg-open >/dev/null 2>&1; then
                print_status "Opening router page..." "info"
                xdg-open "http://$CURRENT_GATEWAY"
                return 0
            fi
        fi
    fi

    # Fallback: Bekannte IPs durchprobieren
    print_status "Trying common router addresses..." "info"
    for ip in "${COMMON_GATEWAYS[@]}"; do
        debug "Trying IP: $ip"
        if ping -c 1 -W 1 "$ip" >/dev/null 2>&1; then
            print_status "Found router at $ip" "success"
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "http://$ip"
                return 0
            fi
        fi
    done

    print_status "Could not find router automatically" "error"
    print_status "Common router addresses:" "info"
    printf '%s\n' "${COMMON_GATEWAYS[@]}" | while read -r ip; do
        print_status "Try: http://$ip" "info"
    done
    return 1
}

# Optional: Port-Check Funktion
check_port() {
    local ip="$1"
    local port="$2"
    debug "Checking port $port on $ip"
    nc -z -w1 "$ip" "$port" >/dev/null 2>&1
}