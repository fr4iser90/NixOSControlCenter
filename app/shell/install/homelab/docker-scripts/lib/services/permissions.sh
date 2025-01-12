#!/bin/bash

# Guard gegen mehrfaches Laden
if [ -n "${_PERMISSIONS_SERVICE_LOADED+x}" ]; then
    return 0
fi
_PERMISSIONS_SERVICE_LOADED=1

# Setze VIRT_USER wenn nicht definiert
VIRT_USER=${VIRT_USER:-$(whoami)}

# ==============================================
# Permission Management Functions
# ==============================================

# Set standard permissions for files and directories
set_standard_permissions() {
    local target_dir="$1"
    print_status "Setting permissions for $target_dir" "info"

    # Set base permissions
    find "$target_dir" -type d -exec chmod 755 {} \;
    find "$target_dir" -type f -exec chmod 644 {} \;

    # Make scripts executable
    find "$target_dir" -type f -name "*.sh" -exec chmod +x {} \;
}

# Set ownership for files and directories
set_ownership() {
    local target_dir="$1"
    local owner="$2"
    print_status "Setting ownership for $target_dir to $owner" "info"

    chown -R "$owner:$owner" "$target_dir"
}

# Main function to set all permissions
setup_permissions() {
    print_status "Setting up file permissions..." "info"

    # Set permissions for both directories
    set_standard_permissions "$DOCKER_BASE_DIR"
    set_standard_permissions "$DOCKER_SCRIPTS_DIR"

    # Set ownership (VIRT_USER sollte jetzt immer definiert sein)
    set_ownership "$DOCKER_BASE_DIR" "$VIRT_USER"
    set_ownership "$DOCKER_SCRIPTS_DIR" "$VIRT_USER"
    print_status "File permissions and ownership set successfully!" "success"
    return 0
}