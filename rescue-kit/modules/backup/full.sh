#!/bin/bash

# Full system backup
backup_full() {
    local backup_dir=$1
    log "Starting full system backup to $backup_dir..."
    
    # Create backup directory
    mkdir -p $backup_dir || {
        log "Error: Failed to create backup directory"
        return 1
    }
    
    # Exclude directories
    local exclude=(
        "--exclude=/proc"
        "--exclude=/sys"
        "--exclude=/dev"
        "--exclude=/run"
        "--exclude=/tmp"
        "--exclude=$backup_dir"
    )
    
    # Perform backup
    rsync -a "${exclude[@]}" "$MOUNT_DIR/" "$backup_dir" || {
        log "Error: Full system backup failed"
        return 1
    }
    
    log "Full system backup completed"
    return 0
}
