#!/bin/bash

# Verify root privileges
verify_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Error: Script must be run as root"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    
    # Unmount bind mounts
    for mount_point in proc sys dev run; do
        if mount | grep -q "$MOUNT_DIR/$mount_point"; then
            umount -l "$MOUNT_DIR/$mount_point" || {
                echo "Warning: Failed to unmount $MOUNT_DIR/$mount_point"
            }
        fi
    done
    
    # Unmount main partitions
    if mount | grep -q "$MOUNT_DIR/boot"; then
        umount "$MOUNT_DIR/boot" || {
            echo "Warning: Failed to unmount boot partition"
        }
    fi
    
    if mount | grep -q "$MOUNT_DIR"; then
        umount "$MOUNT_DIR" || {
            echo "Warning: Failed to unmount root partition"
        }
    fi
    
    echo "Cleanup completed"
}

# Trap signals for cleanup
trap cleanup EXIT


# Handler to update partitions
update_partition_handler() {
    echo "Updating partition configurations..."
    set_root_part
    set_boot_part
    echo "Partition configurations updated successfully."
}

# Configuration setters
set_root_part() {
    read -p "Enter root partition (e.g. /dev/nvme0n1p2): " ROOT_PART
    echo "Root partition set to: $ROOT_PART"
    export ROOT_PART
}

set_boot_part() {
    read -p "Enter boot partition (e.g. /dev/nvme0n1p1): " BOOT_PART
    echo "Boot partition set to: $BOOT_PART"
    export BOOT_PART
}

set_mount_dir() {
    read -p "Enter mount directory (e.g. /mnt): " MOUNT_DIR
    echo "Mount directory set to: $MOUNT_DIR"
    export MOUNT_DIR
}

set_backup_dir() {
    read -p "Enter backup directory (e.g. /backup): " BACKUP_DIR
    echo "Backup directory set to: $BACKUP_DIR"
    export BACKUP_DIR
}

set_log_file() {
    read -p "Enter log file path (e.g. /var/log/rescue-kit.log): " LOG_FILE
    echo "Log file set to: $LOG_FILE"
    export LOG_FILE
}
