#!/bin/bash

# Standard script setup
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOCKER_SCRIPTS_DIR="/home/docker/docker-scripts"

# Source core imports
source "${DOCKER_SCRIPTS_DIR}/lib/core/imports.sh"

# Guard gegen mehrfaches Laden
if [ -n "${_PLEX_ENV_LOADED+x}" ]; then
    return 0
fi
_PLEX_ENV_LOADED=1

# Script configuration
SERVICE_NAME="plex"
ENV_FILE="plex.env"

print_header "Updating Plex Environment"

# Get service directory
BASE_DIR=$(get_docker_dir "$SERVICE_NAME")
if [ $? -ne 0 ]; then
    print_status "Failed to get $SERVICE_NAME directory" "error"
    exit 1
fi

# Function to prompt for PLEX_CLAIM token
prompt_claim_token() {
    print_status "Please open https://plex.${DOMAIN}/claim and copy the token" "info"
    local token
    token=$(prompt_input "PLEX_CLAIM token" $INPUT_TYPE_TOKEN)
    echo "$token"
}

# Get the PLEX_CLAIM token
print_status "Getting Plex claim token..." "info"
PLEX_CLAIM=$(prompt_claim_token)

# Define environment variables
new_values=(
    "PLEX_CLAIM:$PLEX_CLAIM"
)

# Update environment file
if update_env_file "$BASE_DIR" "$ENV_FILE" "${new_values[@]}"; then
    print_status "Plex claim token has been updated: $PLEX_CLAIM" "success"
else
    print_status "Failed to update Plex claim token" "error"
    exit 1
fi