#!/bin/bash

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOCKER_SCRIPTS_DIR="/home/docker/docker-scripts"

# Source core imports
source "${DOCKER_SCRIPTS_DIR}/lib/core/imports.sh"

# Guard gegen mehrfaches Laden
if [ -n "${_DDNS_CONFIG_LOADED+x}" ]; then
    return 0
fi
_DDNS_CONFIG_LOADED=1

# Script configuration
SERVICE_NAME="ddns-updater"
CONF_FILE="config/ddclient.conf"

print_header "Updating DDNS Configuration"

# Get service directory
BASE_DIR=$(get_docker_dir "$SERVICE_NAME")
if [ $? -ne 0 ]; then
    print_status "Failed to get $SERVICE_NAME directory" "error"
    exit 1
fi

update_dns_config() {
    # Validate domain
    print_status "Validating domain..." "info"
    if ! validate_domain; then
        print_status "Domain validation failed" "error"
        return 1
    fi

    print_status "Updating ddclient configuration for $DNS_PROVIDER_CODE" "info"

    # Entkommentiere nur den passenden Block
    sed -i -E "/^## /{h;d}; /^#?protocol=$DNS_PROVIDER_CODE/ {x;s/^## /\n/;x;:a;N;/\n## /!ba;s/#//g;s/\\//g}" "$BASE_DIR/$CONF_FILE"

    print_status "DDNS configuration updated successfully" "success"
    return 0
}


# Run if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if ! update_dns_config; then
        exit 1
    fi
fi