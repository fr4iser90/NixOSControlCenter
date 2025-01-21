#!/bin/bash

# Rebuild NixOS system
rebuild_system() {
    log "Starting system rebuild..."
    
    # Verify mounted partitions
    if ! mount | grep -q $MOUNT_DIR; then
        log "Error: Partitions not mounted"
        return 1
    fi
    
    # Check for NixOS configuration
    if [ ! -d "$MOUNT_DIR/etc/nixos" ]; then
        log "Error: NixOS configuration not found in $MOUNT_DIR/etc/nixos"
        return 1
    fi
    
    # Rebuild system
    log "Running nixos-install..."
    nixos-install --root $MOUNT_DIR || {
        log "Error: System rebuild failed"
        return 1
    }
    
    log "System rebuild completed successfully"
    return 0
}
