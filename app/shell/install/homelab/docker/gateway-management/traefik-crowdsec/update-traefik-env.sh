#!/bin/bash

# Standard script setup
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOCKER_SCRIPTS_DIR="/home/docker/docker-scripts"

# Source core imports
source "${DOCKER_SCRIPTS_DIR}/lib/core/imports.sh"

# Guard gegen mehrfaches Laden
if [ -n "${_TRAEFIK_ENV_LOADED+x}" ]; then
    return 0
fi
_TRAEFIK_ENV_LOADED=1

# Script configuration
SERVICE_NAME="traefik-crowdsec"
ENV_FILE="traefik.env"

print_header "Updating Traefik Environment"

# Get service directory
BASE_DIR=$(get_docker_dir "$SERVICE_NAME")
if [ $? -ne 0 ]; then
    print_status "Failed to get $SERVICE_NAME directory" "error"
    exit 1
fi

# Get user info
print_status "Getting user information..." "info"
get_user_info

# Define environment variables
new_values=(
    "PGID:$USER_GID"
    "DNS_PROVIDER:$DNS_PROVIDER_CODE"  # Von DNS Provider Select
)

# Add all DNS credentials from get_dns_credentials
for var in $(env | grep -E '^(AWS_|CLOUDFLARE_|GOOGLE_|AZURE_|DO_)' | cut -d= -f1); do
    new_values+=("$var:${!var}")
done

# Update environment file
if update_env_file "$BASE_DIR" "$ENV_FILE" "${new_values[@]}"; then
    print_status "Traefik environment file has been updated" "success"
else
    print_status "Failed to update environment file" "error"
    exit 1
fi


