#!/bin/bash

# Guard gegen mehrfaches Laden
if [ -n "${_PORTS_UTILS_LOADED+x}" ]; then
    return 0
fi
_PORTS_UTILS_LOADED=1

# Benötigte Funktionen laden
source "${DOCKER_LIB_DIR}/utils/format/output.sh"

# Port Definitionen
declare -A REQUIRED_PORTS=(
    # Web Services (Traefik)
    ["HTTP"]="80:TCP"
    ["HTTPS"]="443:TCP"
    
    # Security (Optional)
    ["SSH_HONEYPOT"]="2222:TCP"
    
    # VPN (Optional)
    ["WIREGUARD"]="51820:UDP"
)

# Port-Check Funktion
check_port() {
    local ip="$1"
    local port="$2"
    local protocol="${3:-tcp}"
    
    case "$protocol" in
        tcp|TCP)
            nc -z -w1 "$ip" "$port" >/dev/null 2>&1
            ;;
        udp|UDP)
            nc -zu -w1 "$ip" "$port" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# Port-Liste anzeigen
list_required_ports() {
    print_status "Required Ports:" "info"
    print_status "These ports must be forwarded in your router:" "info"
    
    for port_name in "${!REQUIRED_PORTS[@]}"; do
        local port_info="${REQUIRED_PORTS[$port_name]}"
        local port="${port_info%:*}"
        local protocol="${port_info#*:}"
        
        print_status "$port_name: $port ($protocol)" "info"
    done
}

# Port-Forwarding Anleitung
show_port_forwarding_guide() {
    print_header "Port Forwarding Guide"
    
    print_status "1. Access your router's configuration page" "info"
    if ! find_router; then
        print_status "Could not open router page automatically" "warn"
    fi
    
    print_status "2. Look for 'Port Forwarding' or 'NAT' settings" "info"
    
    print_status "3. Required ports to forward:" "info"
    list_required_ports
    
    print_status "4. Forward these ports to: $(hostname -I | awk '{print $1}')" "info"
    
    if prompt_confirmation "Would you like to test the ports now?"; then
        test_port_forwarding
    fi
}

# Port-Forwarding testen
test_port_forwarding() {
    print_status "Testing port forwarding..." "info"
    
    local EXTERNAL_IP
    EXTERNAL_IP=$(curl -s ifconfig.me)
    
    if [ -z "$EXTERNAL_IP" ]; then
        print_status "Could not determine external IP" "error"
        return 1
    fi
    
    print_status "External IP: $EXTERNAL_IP" "info"
    
    # Wichtige Ports testen
    for port_name in "HTTP" "HTTPS"; do
        local port_info="${REQUIRED_PORTS[$port_name]}"
        local port="${port_info%:*}"
        
        if check_port "$EXTERNAL_IP" "$port" "tcp"; then
            print_status "Port $port ($port_name) is open" "success"
        else
            print_status "Port $port ($port_name) is closed" "error"
        fi
    done
}