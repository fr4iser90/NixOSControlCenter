#!/bin/bash

# Set up bind mounts for chroot
setup_bind_mounts() {
    log "Setting up bind mounts..."
    
    local required_mounts=("/proc" "/sys" "/dev" "/run")
    
    for mount_point in "${required_mounts[@]}"; do
        if [ -d "$mount_point" ]; then
            mkdir -p $MOUNT_DIR$mount_point
            mount --bind $mount_point $MOUNT_DIR$mount_point || { 
                log "Failed to bind mount $mount_point"; 
                return 1
            }
        else
            log "Warning: $mount_point does not exist"
        fi
    done
    
    log "Bind mounts set up successfully"
    return 0
}

# Main bind mounts function
bind_mounts() {
    if ! setup_bind_mounts; then
        log "Error: Failed to set up bind mounts"
        return 1
    fi
    return 0
}
