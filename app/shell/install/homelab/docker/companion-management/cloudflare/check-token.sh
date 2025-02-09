#!/bin/bash

# Standard script setup
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOCKER_SCRIPTS_DIR="/home/docker/docker-scripts"
source "${DOCKER_SCRIPTS_DIR}/lib/core/imports.sh"

SERVICE_NAME="cloudflare"
ENV_FILE="cloudflare-companion.env"
BASE_DIR=$(get_docker_dir "$SERVICE_NAME")

check_auth() {
    print_status "Checking Cloudflare authentication..." "info"
    
    # Check if container is running
    if ! docker ps | grep -q "cloudflare-companion"; then
        print_status "Container is not running, starting it..." "warn"
        cd "$BASE_DIR" && docker-compose up -d
        sleep 10
    fi
    
    # Show last logs
    print_status "Checking container logs..." "info"
    LOG_OUTPUT=$(docker logs --tail 50 cloudflare-companion 2>&1)
    echo "$LOG_OUTPUT"
    
    # Check for actual authentication errors, ignoring existing DNS record errors
    if echo "$LOG_OUTPUT" | grep -iE "(unauthorized|invalid credentials|CloudFlareAPIError)"; then
        print_status "Authentication error detected!" "error"
        return 1
    fi
    
    print_status "No authentication issues found." "success"
    return 0
}

switch_to_global_key() {
    print_status "Switching to Global API Key..." "info"
    
    # Backup current env file
    cp "$BASE_DIR/$ENV_FILE" "$BASE_DIR/${ENV_FILE}.bak"
    
    # Check if CF_API_KEY exists
    if [ -n "${CF_API_KEY:-}" ]; then
        sed -i 's/^CF_TOKEN/#CF_TOKEN/' "$BASE_DIR/$ENV_FILE"
        sed -i "s/#CF_API_KEY=.*/CF_API_KEY=$CF_API_KEY/" "$BASE_DIR/$ENV_FILE"
        docker restart cloudflare-companion
    else
        print_status "Global API Key is not available, skipping switch." "info"
    fi
}

# Main logic
if ! check_auth; then
    print_status "Token authentication might have failed! Checking alternatives..." "warn"
    
    if [ -n "${CF_API_KEY:-}" ]; then
        print_status "Trying with Global API Key..." "warn"
        switch_to_global_key
        if check_auth; then
            print_status "Global API Key authentication successful." "success"
        else
            print_status "Global API Key also failed, but continuing..." "error"
        fi
    else
        print_status "No Global API Key available, but continuing..." "warn"
    fi
else
    print_status "Cloudflare authentication is fine." "success"
fi
