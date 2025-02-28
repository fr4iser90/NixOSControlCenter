#!/bin/bash

# Standard script setup
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOCKER_SCRIPTS_DIR="/home/docker/docker-scripts"

# Source core imports
source "${DOCKER_SCRIPTS_DIR}/lib/core/imports.sh"

# Guard gegen mehrfaches Laden
if [ -n "${_PORTAINER_COMPOSE_LOADED+x}" ]; then
    return 0
fi
_PORTAINER_COMPOSE_LOADED=1

# Script configuration
SERVICE_NAME="portainer"
COMPOSE_FILE="docker-compose.yml"

print_header "Updating Portainer Configuration"

# Get service directory
BASE_DIR=$(get_docker_dir "$SERVICE_NAME")
if [ $? -ne 0 ]; then
    print_status "Failed to get $SERVICE_NAME directory" "error"
    exit 1
fi

# Get user info
print_status "Getting user information..." "info"
if ! get_user_info; then
    print_status "Failed to get user information" "error"
    exit 1
fi

# Update compose file
print_status "Updating Docker Compose file..." "info"
if update_compose_file "$BASE_DIR" "$COMPOSE_FILE" "$USER_UID" "$USER_GID"; then
    print_status "Portainer Docker Compose file has been updated" "success"
else
    print_status "Failed to update Docker Compose file" "error"
    exit 1
fi