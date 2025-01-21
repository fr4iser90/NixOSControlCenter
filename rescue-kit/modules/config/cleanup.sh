#!/bin/bash

# Cleanup function
cleanup() {
    log "Cleaning up..."
    
    # Unmount bind mounts
    for mount_point in proc sys dev run; do
        if mount | grep -q "$MOUNT_DIR/$mount_point"; then
            umount -l "$MOUNT_DIR/$mount_point" || {
                log "Warning: Failed to unmount $MOUNT_DIR/$mount_point"
            }
        fi
    done
    
    # Unmount main partitions
    if mount | grep -q "$MOUNT_DIR/boot"; then
        umount "$MOUNT_DIR/boot" || {
            log "Warning: Failed to unmount boot partition"
        }
    fi
    
    if mount | grep -q "$MOUNT_DIR"; then
        umount "$MOUNT_DIR" || {
            log "Warning: Failed to unmount root partition"
        }
    fi
    
    log "Cleanup completed"
}

# Trap signals for cleanup
trap cleanup EXIT
