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

# Update compose file
if update_compose_file "$BASE_DIR" "$COMPOSE_FILE" "$USER_UID" "$USER_GID"; then
    print_status "Plex Docker Compose file has been updated" "success"
else
    print_status "Failed to update Docker Compose file" "error"
    exit 1
fi