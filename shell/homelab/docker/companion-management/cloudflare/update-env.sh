#!/bin/bash

# Standard script setup
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOCKER_SCRIPTS_DIR="/home/docker/docker-scripts"

# Source core imports
source "${DOCKER_SCRIPTS_DIR}/lib/core/imports.sh"

# Guard gegen mehrfaches Laden
if [ -n "${_CLOUDFLARE_COMPANION_LOADED+x}" ]; then
    return 0
fi
_CLOUDFLARE_COMPANION_LOADED=1

# Script configuration
SERVICE_NAME="cloudflare"
ENV_FILE="cloudflare-companion.env"

print_header "Updating Cloudflare Companion Configuration"

# Get service directory
BASE_DIR=$(get_docker_dir "$SERVICE_NAME")
if [ $? -ne 0 ]; then
    print_status "Failed to get $SERVICE_NAME directory" "error"
    exit 1
fi


# Check if Cloudflare credentials exist FIRST
print_status "Checking Cloudflare credentials..." "info"
if [ -z "${CF_API_EMAIL:-}" ] || [ -z "${CF_TOKEN:-}" ] || [ -z "${CF_ZONE_ID:-}" ]; then
    print_status "No Cloudflare credentials found" "warn"
    print_status "Skipping Cloudflare configuration" "warn"
    exit 0
fi

# Validate domain
print_status "Validating domain..." "info"
if ! validate_domain; then
    print_status "Domain validation failed" "error"
    exit 1
fi

# Now validate the credentials that we know exist
print_status "Validating Cloudflare credentials..." "info"

# Email validation
if [[ ! "$CF_API_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    print_status "Invalid Cloudflare email format: $CF_API_EMAIL" "warn"
    print_status "Skipping Cloudflare configuration" "warn"
    exit 0
fi

# API Key validation
if [[ ${#CF_TOKEN} -lt 30 ]]; then
    print_status "Cloudflare API token seems too short" "warn"
    print_status "Skipping Cloudflare configuration" "warn"
    exit 0
fi

# Zone ID validation
if [[ ! "$CF_ZONE_ID" =~ ^[a-f0-9]{32}$ ]]; then
    print_status "Invalid Cloudflare Zone ID format" "warn"
    print_status "Skipping Cloudflare configuration" "warn"
    exit 0
fi

print_status "Using existing Cloudflare credentials..." "info"

# Store credentials
store_service_credentials "$SERVICE_NAME" "$CF_API_EMAIL" "$CF_TOKEN"

# Update environment file
new_values=(
    "#CF_EMAIL:$CF_API_EMAIL"
    "#CF_API_KEY:$CF_API_KEY"
    "CF_TOKEN:$CF_TOKEN"
    "DOMAIN1_ZONE_ID:$CF_ZONE_ID"
    "TARGET_DOMAIN:$DOMAIN"
    "DOMAIN1:$DOMAIN"
)

if update_env_file "$BASE_DIR" "$ENV_FILE" "${new_values[@]}"; then
    print_status "Cloudflare configuration updated successfully" "success"
    
    # Definiere den absoluten Pfad zum Script
    CHECK_SCRIPT="${BASE_DIR}/check-token.sh"
    
    print_status "Looking for check script at: $CHECK_SCRIPT" "info"
    
    # Prüfe ob die Datei existiert und ausführbar ist
    if [ -f "$CHECK_SCRIPT" ]; then
        # Setze Ausführungsrechte
        chmod +x "$CHECK_SCRIPT"
        print_status "Set execute permissions for check-token.sh" "info"
        
        # Starte Container falls nötig
        if ! docker ps | grep -q "cloudflare-companion"; then
            print_status "Starting Cloudflare companion container..." "info"
            cd "$BASE_DIR" && docker-compose up -d
            sleep 5
        fi
        
        # Führe Check mit bash explizit aus
        print_status "Validating token configuration..." "info"
        bash "$CHECK_SCRIPT"
    else
        print_status "check-token.sh not found at: $CHECK_SCRIPT" "warn"
        ls -la "$BASE_DIR"  # Debug: Zeige Verzeichnisinhalt
    fi
else
    print_status "Failed to update Cloudflare configuration" "error"
    exit 1
fi