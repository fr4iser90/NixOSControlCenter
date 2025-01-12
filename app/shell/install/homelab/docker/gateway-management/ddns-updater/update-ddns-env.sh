#!/bin/bash

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOCKER_SCRIPTS_DIR="/home/docker/docker-scripts"

# Source core imports
source "${DOCKER_SCRIPTS_DIR}/lib/core/imports.sh"

# Guard gegen mehrfaches Laden
if [ -n "${_DDNS_UPDATER_LOADED+x}" ]; then
    return 0
fi
_DDNS_UPDATER_LOADED=1

# Script configuration
SERVICE_NAME="ddns-updater"
ENV_FILE="ddns-updater.env"

print_header "Updating DDNS Updater Environment"

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
    "PUID:$USER_UID"
    "PGID:$USER_GID"
)

# Update environment file
if update_env_file "$BASE_DIR" "$ENV_FILE" "${new_values[@]}"; then
    print_status "Environment file has been updated" "success"
else
    print_status "Failed to update environment file" "error"
    exit 1
fi