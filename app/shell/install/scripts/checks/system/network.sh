#!/usr/bin/env bash


log_section "Detecting Network Configuration"

# Network Interfaces
log_info "Network Interfaces:"
if command -v ip &> /dev/null; then
    # Alle Interfaces mit Status
    ip -br addr show | while read -r line; do
        if_name=$(echo "$line" | awk '{print $1}')
        if_status=$(echo "$line" | awk '{print $2}')
        
        # Separate IPv4 and IPv6
        ipv4_addrs=$(ip -4 addr show "$if_name" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+')
        ipv6_addrs=$(ip -6 addr show "$if_name" | grep -oP '(?<=inet6\s)[0-9a-f:]+/\d+' | grep -v '^fe80' | sort)
        
        # Farbiger Status
        if [ "$if_status" = "UP" ]; then
            status_color=$GREEN
        else
            status_color=$RED
        fi
        
        echo -e "  ${CYAN}${if_name}${NC}:"
        echo -e "    Status  : ${status_color}${if_status}${NC}"
        
        # IPv4
        if [ -n "$ipv4_addrs" ]; then
            echo -e "    IPv4    : ${GRAY}${ipv4_addrs}${NC}"
        fi
        
        # IPv6 (ohne Link-Local)
        if [ -n "$ipv6_addrs" ]; then
            first=true
            while IFS= read -r addr; do
                if [ -n "$addr" ]; then
                    if [ "$first" = true ]; then
                        echo -e "    IPv6    : ${GRAY}${addr}${NC}"
                        first=false
                    else
                        echo -e "              ${GRAY}${addr}${NC}"
                    fi
                fi
            done <<< "$ipv6_addrs"
        fi
        
        # MAC-Adresse
        mac=$(ip link show "$if_name" | grep -o 'link/ether.*' | awk '{print $2}')
        if [ -n "$mac" ]; then
            echo -e "    MAC     : ${GRAY}${mac}${NC}"
        fi
        
        echo "" # Leerzeile zwischen Interfaces
    done
fi

# DNS Configuration
log_info "DNS Configuration:"
if [ -f "/etc/resolv.conf" ]; then
    echo "  Nameservers:"
    grep "^nameserver" /etc/resolv.conf | while read -r line; do
        ns=$(echo "$line" | awk '{print $2}')
        echo -e "    ${CYAN}${ns}${NC}"
    done
    
    # Search Domains
    search_domains=$(grep "^search" /etc/resolv.conf | awk '{$1=""; print $0}' | tr -s ' ')
    if [ -n "$search_domains" ]; then
        echo "  Search Domains:"
        echo -e "    ${GRAY}${search_domains}${NC}"
    fi
else
    echo -e "  ${RED}No resolv.conf found${NC}"
fi

# Default Gateway
log_info "Routing:"
if command -v ip &> /dev/null; then
    echo "  Default Gateway:"
    # IPv4
    ipv4_route=$(ip -4 route show default)
    if [ -n "$ipv4_route" ]; then
        echo -e "    IPv4: ${CYAN}${ipv4_route}${NC}"
    fi
    # IPv6
    ipv6_route=$(ip -6 route show default)
    if [ -n "$ipv6_route" ]; then
        echo -e "    IPv6: ${CYAN}${ipv6_route}${NC}"
    fi
fi

# Network Manager Status
log_info "Network Management:"
if command -v nmcli &> /dev/null; then
    echo "  NetworkManager:"
    # Allgemeiner Status
    nm_status=$(nmcli general status)
    state=$(echo "$nm_status" | tail -n1 | awk '{print $1}')
    connectivity=$(echo "$nm_status" | tail -n1 | awk '{print $2}')
    echo -e "    State       : ${GREEN}${state}${NC}"
    echo -e "    Connectivity: ${GREEN}${connectivity}${NC}"
    
    # WLAN Status
    if nmcli device | grep -q "wifi.*connected"; then
        echo "  WiFi Networks:"
        nmcli -t -f ACTIVE,SIGNAL,SSID,SECURITY device wifi list | grep '^yes' | while read -r line; do
            IFS=':' read -r active signal ssid security <<< "$line"
            if [ -n "$ssid" ]; then
                echo -e "    Connected to: ${CYAN}${ssid}${NC}"
                echo -e "    Signal     : ${GREEN}${signal}%${NC}"
                echo -e "    Security   : ${GRAY}${security}${NC}"
            fi
        done
    fi
else
    echo -e "  ${YELLOW}NetworkManager not available${NC}"
fi

# Firewall Status
log_info "Firewall Status:"
if command -v firewall-cmd &> /dev/null; then
    if systemctl is-active --quiet firewalld; then
        echo -e "  FirewallD: ${GREEN}Active${NC}"
        echo "  Active Zones:"
        firewall-cmd --get-active-zones | while read -r zone; do
            if [ -n "$zone" ]; then
                interfaces=$(firewall-cmd --zone="$zone" --list-interfaces 2>/dev/null)
                if [ -n "$interfaces" ]; then
                    echo -e "    ${CYAN}${zone}${NC}:"
                    echo -e "      Interfaces: ${GRAY}${interfaces}${NC}"
                fi
            fi
        done
    else
        echo -e "  FirewallD: ${RED}Inactive${NC}"
    fi
else
    echo -e "  ${YELLOW}No firewall service detected${NC}"
fi

# Open Ports
log_info "Open Ports (listening):"
if command -v ss &> /dev/null; then
    echo "  TCP:"
    ss -tlnp 2>/dev/null | grep LISTEN | sort -k4 | while read -r line; do
        local_addr=$(echo "$line" | awk '{print $4}')
        process=$(echo "$line" | grep -o 'users:.*' | sed 's/users:[[({]//g' | sed 's/[})].*//g')
        port=$(echo "$local_addr" | cut -d: -f2)
        if [ -n "$process" ]; then
            echo -e "    Port ${CYAN}${port}${NC} (${GRAY}${process}${NC})"
        else
            echo -e "    Port ${CYAN}${port}${NC}"
        fi
    done
    
    echo "  UDP:"
    ss -ulnp 2>/dev/null | sort -k4 | while read -r line; do
        local_addr=$(echo "$line" | awk '{print $4}')
        process=$(echo "$line" | grep -o 'users:.*' | sed 's/users:[[({]//g' | sed 's/[})].*//g')
        port=$(echo "$local_addr" | cut -d: -f2)
        if [ "$local_addr" != "Local" ] && [ -n "$port" ]; then
            if [ -n "$process" ]; then
                echo -e "    Port ${CYAN}${port}${NC} (${GRAY}${process}${NC})"
            else
                echo -e "    Port ${CYAN}${port}${NC}"
            fi
        fi
    done | sort -u
fi