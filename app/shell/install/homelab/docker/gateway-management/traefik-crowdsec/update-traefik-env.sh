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
CONF_FILE="traefik/traefik.yml"
ACME_LETSENCRYPT="traefik/acme_letsencrypt.json"
TLS_LETSENCRYPT="traefik/tls_letsencrypt.json"

print_header "Updating Traefik Environment"

# Get service directory
BASE_DIR=$(get_docker_dir "$SERVICE_NAME")
if [ $? -ne 0 ]; then
    print_status "Failed to get $SERVICE_NAME directory" "error"
    exit 1
fi

# Set proper permissions for sensitive files
print_status "Setting correct permissions for Traefik files..." "info"
chmod 600 "$BASE_DIR/$ACME_LETSENCRYPT" "$BASE_DIR/$TLS_LETSENCRYPT"

# Get user info
print_status "Getting user information..." "info"
get_user_info

# Define environment variables
new_values=(
    "PUID:$USER_UID"
    "PGID:$USER_GID"
)

new_traefik_yml_values=(
    "EMAIL:$EMAIL"
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

if update_conf_file "$BASE_DIR" "$CONF_FILE" "${new_traefik_yml_values[@]}"; then
    print_status "Traefik config file has been updated" "success"
else
    print_status "Failed to update Traefik config file" "error"
    exit 1
fi
