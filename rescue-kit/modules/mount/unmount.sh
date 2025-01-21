#!/bin/bash

# Unmount all partitions and bind mounts
unmount_all() {
    log "Unmounting all partitions..."
    
    # Unmount bind mounts first
    local mounted_points=($(grep $MOUNT_DIR /proc/mounts | awk '{print $2}' | sort -r))
    
    for point in "${mounted_points[@]}"; do
        umount $point || log "Warning: Failed to unmount $point"
    done
    
    # Finally unmount root
    umount $MOUNT_DIR || log "Warning: Failed to unmount root partition"
    
    log "Unmounting complete"
}
