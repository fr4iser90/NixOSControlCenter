#!/bin/bash

# Debug mode
# PS4='+ ${BASH_SOURCE[0]}:${LINENO}: '
# set -x

# Standard script setup - DO NOT MODIFY
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOCKER_SCRIPTS_DIR="$(dirname "$SCRIPT_PATH")"

# Debug output
echo "Script path: $SCRIPT_PATH"
echo "Script dir: $DOCKER_SCRIPTS_DIR"
echo "Current dir: $(pwd)"

# Verify script directory
if [ ! -f "${DOCKER_SCRIPTS_DIR}/lib/core/imports.sh" ]; then
    echo "Error: Script directory structure invalid"
    echo "Expected: ${DOCKER_SCRIPTS_DIR}/lib/core/imports.sh"
    exit 1
fi

# Source imports
source "${DOCKER_SCRIPTS_DIR}/lib/core/imports.sh"

# Start with header and credential preference
print_header "Homelab Setup"
ask_credential_preference

# Prevent running as root
if [ "$EUID" -eq 0 ]; then
    print_status "This script should NOT be run as root" "error"
    print_status "Please run as normal user who is member of the docker group" "info"
    exit 1
fi

# Verify docker group membership
if ! groups | grep -q docker; then
    print_status "Current user must be in the docker group" "error"
    print_status "Run: sudo usermod -aG docker $USER" "info"
    print_status "Then log out and back in" "info"
    exit 1
fi

# Initialize components
print_header "Component Initialization"

# Set permissions
print_status "Setting up permissions..." "info"
if ! setup_permissions; then
    print_status "Failed to set permissions" "error"
    exit 1
fi

# Port-Forwarding Info
print_header "Network Setup"
print_status "The following ports need to be forwarded in your router:" "info"
list_required_ports

if prompt_confirmation "Would you like to open your router configuration page now?"; then
    if ! find_router; then
        print_status "Could not open router page automatically" "warn"
        print_status "Please configure port forwarding manually" "info"
    else
        print_status "Please configure the listed ports in your router" "info"
        if prompt_confirmation "Continue when port forwarding is configured?"; then
            test_port_forwarding
        fi
    fi
fi

# Initialize security infrastructure
print_status "Initializing security infrastructure..." "info"
if ! initialize_gateway; then
    print_status "Failed to initialize security infrastructure" "error"
    exit 1
fi

# Initialize all remaining services
print_status "Initializing application services..." "info"
if ! initialize_services; then
    print_status "Failed to initialize docker services" "error"
    exit 1
fi

# Final success message
print_header "Setup Complete"
print_status "Homelab initialization completed successfully!" "success"