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

# Validate NixOS configuration
validate_configuration() {
    log "Validating NixOS configuration..."
    
    if ! nixos-container --root $MOUNT_DIR run -- nixos-rebuild dry-build; then
        log "Error: NixOS configuration validation failed"
        return 1
    fi
    
    log "Configuration validated successfully"
    return 0
}

# Verify system after rebuild
verify_rebuild() {
    log "Verifying system after rebuild..."
    
    # Check for successful installation
    if [ ! -f "$MOUNT_DIR/etc/NIXOS" ]; then
        log "Error: NixOS installation verification failed"
        return 1
    fi
    
    # Check for bootloader installation
    if [ -n "$BOOT_PART" ] && [ ! -f "$MOUNT_DIR/boot/loader/entries/nixos-generation-1.conf" ]; then
        log "Error: Bootloader installation verification failed"
        return 1
    fi
    
    log "System verification successful"
    return 0
}

# Full rebuild process
full_rebuild() {
    if ! rebuild_system; then
        return 1
    fi
    
    if ! validate_configuration; then
        return 1
    fi
    
    if ! verify_rebuild; then
        return 1
    fi
    
    log "System rebuild process completed"
    return 0
}
