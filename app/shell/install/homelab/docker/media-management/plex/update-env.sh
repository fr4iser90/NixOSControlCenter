#!/bin/bash

# Standard script setup
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOCKER_SCRIPTS_DIR="/home/docker/docker-scripts"

# Source core imports
source "${DOCKER_SCRIPTS_DIR}/lib/core/imports.sh"

# Guard gegen mehrfaches Laden
if [ -n "${_PLEX_COMPOSE_LOADED+x}" ]; then
    return 0
fi
_PLEX_COMPOSE_LOADED=1

# Script configuration
SERVICE_NAME="plex"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE="pihole.env"

print_header "Updating Plex Docker Compose"

# Get service directory
BASE_DIR=$(get_docker_dir "$SERVICE_NAME")
if [ $? -ne 0 ]; then
    print_status "Failed to get $SERVICE_NAME directory" "error"
    exit 1
fi

# Get user info
print_status "Getting user information..." "info"
get_user_info

new_values=(
    "PUID:$USER_UID"
    "PGID:$USER_GID"
)

# Update environment file
if update_env_file "$BASE_DIR" "$ENV_FILE" "${new_values[@]}"; then
    print_status "Plex evironment file has been updated" "success"
else
    print_status "Failed to update environment file" "error"
    exit 1
fi