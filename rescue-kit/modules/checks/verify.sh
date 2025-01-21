#!/bin/bash

# Verify system partitions
verify_partitions() {
    log "Verifying partitions..."
    
    # Check if root partition exists
    if [ ! -e "$ROOT_PART" ]; then
        log "Error: Root partition $ROOT_PART not found"
        return 1
    fi
    
    # Check if boot partition exists (if specified)
    if [ -n "$BOOT_PART" ] && [ ! -e "$BOOT_PART" ]; then
        log "Error: Boot partition $BOOT_PART not found"
        return 1
    fi
    
    log "Partitions verified successfully"
    return 0
}
