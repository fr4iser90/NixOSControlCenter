#!/bin/bash

# Mount partitions and set up chroot environment
mount_partitions() {
    log "Mounting partitions..."
    
    # Create mount directory if it doesn't exist
    mkdir -p $MOUNT_DIR || { log "Failed to create mount directory"; return 1; }
    
    # Mount root partition
    mount $ROOT_PART $MOUNT_DIR || { log "Failed to mount root partition"; return 1; }
    
    # Mount boot partition if specified
    if [ -n "$BOOT_PART" ]; then
        mkdir -p $MOUNT_DIR/boot
        mount $BOOT_PART $MOUNT_DIR/boot || { log "Failed to mount boot partition"; return 1; }
    fi
    
    log "Partitions mounted successfully"
}
