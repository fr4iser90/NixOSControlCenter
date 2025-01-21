#!/bin/bash

# Configuration setters
set_root_part() {
    read -p "Enter root partition (e.g. /dev/nvme0n1p2): " ROOT_PART
    log "Root partition set to: $ROOT_PART"
}

set_boot_part() {
    read -p "Enter boot partition (e.g. /dev/nvme0n1p1): " BOOT_PART
    log "Boot partition set to: $BOOT_PART"
}

set_mount_dir() {
    read -p "Enter mount directory (e.g. /mnt): " MOUNT_DIR
    log "Mount directory set to: $MOUNT_DIR"
}

set_backup_dir() {
    read -p "Enter backup directory (e.g. /backup): " BACKUP_DIR
    log "Backup directory set to: $BACKUP_DIR"
}

set_log_file() {
    read -p "Enter log file path (e.g. /var/log/rescue-kit.log): " LOG_FILE
    log "Log file set to: $LOG_FILE"
}