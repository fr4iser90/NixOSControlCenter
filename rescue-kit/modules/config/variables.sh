#!/bin/bash

# Configuration variables
ROOT_PART="/dev/nvme0n1p2"
BOOT_PART="/dev/nvme0n1p1"
USER="UserName"
MOUNT_DIR="/mnt"
BACKUP_DIR="/backup"
LOG_FILE="/var/log/rescue-kit.log"

# Export variables for use in other scripts
export ROOT_PART
export BOOT_PART
export MOUNT_DIR
export BACKUP_DIR
export LOG_FILE
