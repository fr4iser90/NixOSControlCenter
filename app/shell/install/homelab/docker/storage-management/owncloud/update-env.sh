#!/bin/bash

# Standard script setup
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOCKER_SCRIPTS_DIR="/home/docker/docker-scripts"

# Source core imports
source "${DOCKER_SCRIPTS_DIR}/lib/core/imports.sh"

# Guard gegen mehrfaches Laden
if [ -n "${_OWNCLOUD_ENV_LOADED+x}" ]; then
    return 0
fi
_OWNCLOUD_ENV_LOADED=1

# Script configuration
SERVICE_NAME="owncloud"
ENV_FILE="mysql.env"

print_header "Updating OwnCloud Environment"

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

# Set current service for credentials management
export CURRENT_SERVICE="owncloud_mysql"

# Validate domain
print_status "Validating domain..." "info"
if ! validate_domain; then
    print_status "Domain validation failed" "error"
    exit 1
fi

# Generate MySQL credentials
print_status "Generating MySQL credentials..." "info"
MYSQL_ROOT_PASSWORD=$(generate_secure_password)
if [ $? -ne 0 ]; then
    print_status "Failed to generate MySQL password" "error"
    exit 1
fi

# Store credentials
store_service_credentials "$SERVICE_NAME" "mysql_root" "$MYSQL_ROOT_PASSWORD"

# Define environment variables
new_values=(
    "MYSQL_ROOT_PASSWORD:$MYSQL_ROOT_PASSWORD"
    "APACHE_SERVER_NAME:$DOMAIN"
    "PUID:$USER_UID"
    "PGID:$USER_GID"
)

# Update environment file
if update_env_file "$BASE_DIR" "$ENV_FILE" "${new_values[@]}"; then
    print_status "OwnCloud environment updated successfully" "success"
    if [ "$SHOW_CREDENTIALS" = true ]; then
        print_status "MySQL Root Password: $MYSQL_ROOT_PASSWORD" "info"
        print_status "PUID: $USER_UID" "info"
        print_status "PGID: $USER_GID" "info"
    fi
else
    print_status "Failed to update OwnCloud environment" "error"
    exit 1
fi