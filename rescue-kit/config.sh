#!/bin/bash

# Configuration variables
ROOT_PART="/dev/nvme0n1p2"
BOOT_PART="/dev/nvme0n1p1"
MOUNT_DIR="/mnt"
BACKUP_DIR="/backup"
LOG_FILE="/var/log/rescue-kit.log"

# Logging function
log() {
    local message=$1
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message" | tee -a $LOG_FILE
}

# Error handling
handle_error() {
    local message=$1
    log "ERROR: $message"
    exit 1
}

# Verify root privileges
verify_root() {
    if [ "$EUID" -ne 0 ]; then
        handle_error "Script must be run as root"
    fi
}

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
