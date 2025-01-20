#!/bin/bash

# This script should be sourced from rescue.sh, not run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This script is designed to be sourced from rescue.sh"
    echo "Please run the main rescue script instead:"
    echo "  sudo ./rescue.sh"
    exit 1
fi

# Backup essential system data
backup_essential() {
    local backup_dir=$1
    log "Starting essential data backup to $backup_dir..."
    
    # Create backup directory
    mkdir -p $backup_dir || {
        log "Error: Failed to create backup directory"
        return 1
    }
    
    # Essential directories to backup
    local essential_dirs=(
        "/etc/nixos"
        "/etc/ssh"
        "/var/lib"
        "/home"
    )
    
    # Backup each directory
    for dir in "${essential_dirs[@]}"; do
        if [ -d "$MOUNT_DIR$dir" ]; then
            log "Backing up $dir..."
            rsync -a --relative "$MOUNT_DIR$dir" "$backup_dir" || {
                log "Error: Failed to backup $dir"
                return 1
            }
        fi
    done
    
    log "Essential data backup completed"
    return 0
}

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

# Verify backup integrity
verify_backup() {
    local backup_dir=$1
    log "Verifying backup integrity..."
    
    # Check backup directory exists
    if [ ! -d "$backup_dir" ]; then
        log "Error: Backup directory not found"
        return 1
    fi
    
    # Verify essential files
    local essential_files=(
        "$backup_dir/etc/nixos/configuration.nix"
        "$backup_dir/etc/passwd"
        "$backup_dir/etc/group"
    )
    
    for file in "${essential_files[@]}"; do
        if [ ! -f "$file" ]; then
            log "Error: Essential file $file missing in backup"
            return 1
        fi
    done
    
    log "Backup verification successful"
    return 0
}

# Backup menu
backup_menu() {
    local backup_dir=$1
    local mode=$2
    
    case $mode in
        "essential")
            backup_essential $backup_dir
            ;;
        "full")
            backup_full $backup_dir
            ;;
        *)
            log "Error: Invalid backup mode"
            return 1
            ;;
    esac
    
    if ! verify_backup $backup_dir; then
        return 1
    fi
    
    return 0
}
