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
    
    # Debug: Show ENV file content (excluding sensitive data)
    print_status "Current ENV file configuration:" "info"
    grep -v "KEY\|TOKEN" "$BASE_DIR/$ENV_FILE" || true
    
    # Check if container is running
    if ! docker ps | grep -q "cloudflare-companion"; then
        print_status "Container is not running, starting it..." "warn"
        cd "$BASE_DIR" && docker-compose up -d
        sleep 10
    fi
    
    # Show last logs
    print_status "Checking container logs..." "info"
    docker logs --tail 50 cloudflare-companion
    
    # Advanced troubleshooting
    if docker logs cloudflare-companion 2>&1 | grep -i "authentication\|unauthorized\|invalid\|error\|CloudFlareAPIError"; then
        print_status "Found authentication error in logs" "error"
        return 1
    fi
    
    # Check if container is still running or crashed
    if ! docker ps | grep -q "cloudflare-companion"; then
        print_status "Container crashed after start" "error"
        return 1
    fi
    
    return 0
}

switch_to_global_key() {
    print_status "Switching to Global API Key..." "info"
    
    # Backup current env file
    cp "$BASE_DIR/$ENV_FILE" "$BASE_DIR/${ENV_FILE}.bak"
    
    # Check if CF_API_KEY exists
    if [ -n "${CF_API_KEY:-}" ]; then
        # Comment out CF_TOKEN and enable CF_API_KEY
        sed -i 's/^CF_TOKEN/#CF_TOKEN/' "$BASE_DIR/$ENV_FILE"
        sed -i "s/#CF_API_KEY=.*/CF_API_KEY=$CF_API_KEY/" "$BASE_DIR/$ENV_FILE"
        # Restart container
        docker restart cloudflare-companion
    else
        print_status "Global API Key is not available, skipping switch." "info"
    fi
}

# Main logic
if ! check_auth; then
    print_status "Token authentication failed!" "error"
    
    if [ -n "${CF_API_KEY:-}" ]; then
        print_status "Trying with Global API Key..." "warn"
        switch_to_global_key
        
        if check_auth; then
            print_status "Global API Key authentication successful" "success"
            print_status "⚠️  Warning: Using Global API Key is not recommended!" "warn"
        else
            print_status "Global API Key authentication also failed!" "error"
            print_status "Please check your Cloudflare credentials" "error"
            exit 1
        fi
    else
        print_status "No Global API Key available" "error"
        print_status "Please check your Cloudflare Token configuration" "error"
        exit 1
    fi
else
    print_status "Cloudflare authentication successful" "success"
fi
