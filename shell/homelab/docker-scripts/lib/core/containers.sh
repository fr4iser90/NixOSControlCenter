#!/bin/bash

# Guard gegen mehrfaches Laden
if [ -n "${_CONTAINERS_LOADED+x}" ]; then
    return 0
fi
_CONTAINERS_LOADED=1

# Container Kategorien
declare -gA MANAGEMENT_CATEGORIES=(
    ["url-management"]="yourls"
    ["honeypot-management"]="tarpit"
    ["media-management"]="plex jellyfin"
    ["dashboard-management"]="organizr"
    ["adblocker-management"]="pihole"
    ["storage-management"]="owncloud"
    ["gateway-management"]="traefik-crowdsec ddns-updater"  # Ohne companions
    ["companion-management"]="cloudflare"        
    ["password-management"]="bitwarden"
    ["vpn-management"]="wireguard"
    ["system-management"]="portainer watchtower"
)

# Get container category
get_container_category() {
    local container="$1"
    
    for category in "${!MANAGEMENT_CATEGORIES[@]}"; do
        if [[ "${MANAGEMENT_CATEGORIES[$category]}" =~ $container ]]; then
            echo "$category"
            return 0
        fi
    done
    
    return 1
}
