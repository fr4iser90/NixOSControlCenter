#!/bin/bash

# Credentials Storage File
CREDS_FILE="/tmp/homelab_credentials.txt"
FINAL_CREDS_FILE="$HOME/homelab_credentials.txt"

# Initialize credentials file
init_credentials_file() {
    echo "=== Homelab Service Credentials ===" > "$CREDS_FILE"
    echo "Generated: $(date)" >> "$CREDS_FILE"
    echo "=================================" >> "$CREDS_FILE"
    echo >> "$CREDS_FILE"
}

# Store credentials for a service
store_service_credentials() {
    local service="$1"
    local username="$2"
    local password="$3"
    
    echo "Service: $service" >> "$CREDS_FILE"
    echo "Username: $username" >> "$CREDS_FILE"
    echo "Password: $password" >> "$CREDS_FILE"
    echo "-----------------------------------" >> "$CREDS_FILE"
}

# Finalize credentials file
finalize_credentials_file() {
    if [ -f "$CREDS_FILE" ]; then
        mv "$CREDS_FILE" "$FINAL_CREDS_FILE"
        chmod 600 "$FINAL_CREDS_FILE"
        print_status "Credentials saved to: $FINAL_CREDS_FILE" "success"
    fi
}