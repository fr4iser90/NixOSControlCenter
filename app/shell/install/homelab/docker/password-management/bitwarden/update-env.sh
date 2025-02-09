#!/bin/bash

# Standard script setup
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOCKER_SCRIPTS_DIR="/home/docker/docker-scripts"

# Source core imports
source "${DOCKER_SCRIPTS_DIR}/lib/core/imports.sh"

# Guard gegen mehrfaches Laden
if [ -n "${_BITWARDEN_ENV_LOADED+x}" ]; then
    return 0
fi
_BITWARDEN_ENV_LOADED=1

# Script configuration
SERVICE_NAME="bitwarden"
ENV_FILE="bitwarden.env"

print_header "Updating Bitwarden Environment"

# Get service directory
BASE_DIR=$(get_docker_dir "$SERVICE_NAME")
if [ $? -ne 0 ]; then
    print_status "Failed to get $SERVICE_NAME directory" "error"
    exit 1
fi

# Validate domain
print_status "Validating domain..." "info"
if ! validate_domain; then
    print_status "Domain validation failed" "error"
    exit 1
fi

# Get admin credentials
print_status "Setting up admin credentials..." "info"

# Username für Credentials-Speicherung
username="admin"
export CURRENT_USERNAME="$username"

# Password eingabe und Hash
admin_password=$(prompt_input "Bitwarden admin password" $INPUT_TYPE_PASSWORD)
if [ $? -ne 0 ]; then
    print_status "Failed to get admin password" "error"
    exit 1
fi

ADMIN_TOKEN=$(hash_password "$admin_password")
if [ $? -ne 0 ]; then
    print_status "Failed to hash password" "error"
    exit 1
fi

ADMIN_TOKEN_ESCAPED=$(escape_for_sed "$ADMIN_TOKEN")

# Store credentials
store_service_credentials "$SERVICE_NAME" "$username" "$admin_password"

# Define environment variables
new_values=(
    "ADMIN_TOKEN:$ADMIN_TOKEN_ESCAPED"
    "DOMAIN:https://bw.$DOMAIN"
    "WEBSOCKET_ENABLED:true"
    "PUID:$USER_UID"
    "PGID:$USER_GID"
)

# Update environment file
if update_env_file "$BASE_DIR" "$ENV_FILE" "${new_values[@]}"; then
    print_status "Bitwarden environment updated successfully" "success"
    if [ "$SHOW_CREDENTIALS" = true ]; then
        print_status "AdminToken: $ADMIN_TOKEN" "info"
    fi
else
    print_status "Failed to update Bitwarden environment" "error"
    exit 1
fi