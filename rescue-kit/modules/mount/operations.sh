#!/bin/bash

# Set up bind mounts for chroot
setup_bind_mounts() {
    log "Setting up bind mounts..."
    
    local required_mounts=("/proc" "/sys" "/dev" "/run")
    
    for mount_point in "${required_mounts[@]}"; do
        if [ -d "$mount_point" ]; then
            mkdir -p $MOUNT_DIR$mount_point
            mount --bind $mount_point $MOUNT_DIR$mount_point || { 
                log "Failed to bind mount $mount_point"; 
                return 1
            }
        else
            log "Warning: $mount_point does not exist"
        fi
    done
    
    log "Bind mounts set up successfully"
    return 0
}

# Main bind mounts function
bind_mounts() {
    if ! setup_bind_mounts; then
        log "Error: Failed to set up bind mounts"
        return 1
    fi
    return 0
}


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

# Check if partitions are mounted
is_mounted() {
    # Ensure MOUNT_DIR is available
    if [[ -z "$MOUNT_DIR" ]]; then
        echo "Error: MOUNT_DIR is not set"
        return 1
    fi
    
    if mount | grep -q "$MOUNT_DIR"; then
        return 0
    else
        return 1
    fi
}


# Show system status overview
show_status() {
    display_header "Current Status"
    
    key_value "Mounted Partitions" "$(if is_mounted; then echo -e "${UI_COLOR_SUCCESS}Yes${UI_COLOR_FG}"; else echo -e "${UI_COLOR_ERROR}No${UI_COLOR_FG}"; fi)"
    key_value "SSH Daemon" "$(if check_sshd_status &>/dev/null; then echo -e "${UI_COLOR_SUCCESS}Running${UI_COLOR_FG}"; else echo -e "${UI_COLOR_ERROR}Stopped${UI_COLOR_FG}"; fi)"
    key_value "Last Backup" "$(if [ -f "$BACKUP_DIR/last_backup" ]; then cat "$BACKUP_DIR/last_backup"; else echo -e "${UI_COLOR_ERROR}Never${UI_COLOR_FG}"; fi)"
    key_value "Last Rebuild" "$(if [ -f "$REBUILD_LOG" ]; then tail -1 "$REBUILD_LOG"; else echo -e "${UI_COLOR_ERROR}Never${UI_COLOR_FG}"; fi)"
    
    echo ""
}

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
