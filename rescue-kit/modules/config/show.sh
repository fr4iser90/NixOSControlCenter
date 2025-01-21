#!/bin/bash

# Show current configuration
show_config_paths() {
    echo "Current Configuration:"
    echo "Root Partition: $ROOT_PART"
    echo "Boot Partition: $BOOT_PART"
    echo "Mount Directory: $MOUNT_DIR"
    echo "Backup Directory: $BACKUP_DIR"
    echo "Log File: $LOG_FILE"
}