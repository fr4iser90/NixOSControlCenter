#!/bin/bash

# Run all checks
run_all_checks_handler() {
    echo "Running system checks..."
    
    
    if ! detect_partitions; then
        return 1
    fi
    
    if ! verify_partitions; then
        return 1
    fi
    
    if ! list_usb_devices; then
        return 1
    fi
    
    echo "All checks completed successfully"
    return 0
}


# Detect partitions and categorize
detect_partitions_handler() {
    echo "Detecting partitions..."

    local all_partitions=$(lsblk -o NAME,SIZE,FSTYPE,TRAN,MOUNTPOINT -p -n | grep -Ev 'iso9660|loop|zram|swap')
    if [ -z "$all_partitions" ]; then
        echo "Error: No valid partitions found."
        return 1
    fi

    echo "All detected partitions:"
    clean_partitions "$all_partitions"

    local root_candidates=$(echo "$all_partitions" | grep -E 'ext4|xfs|btrfs' | grep -E 'nvme|sata')
    local boot_candidates=$(echo "$all_partitions" | grep -E 'vfat|fat32' | awk '{if ($2 >= 250 * 1024 * 1024) print}')
    local backup_candidates=$(echo "$all_partitions" | grep 'usb')

    prepare_and_save_partition_candidates "$root_candidates" "/tmp/root_candidates"
    prepare_and_save_partition_candidates "$boot_candidates" "/tmp/boot_candidates"
    prepare_and_save_partition_candidates "$backup_candidates" "/tmp/backup_candidates"

    echo "Partition detection completed."
    return 0
}

# Clean detected partitions
clean_partitions() {
    echo "$1" | sed 's/├─//g; s/└─//g; s/│//g'
}

# Save and select partitions
suggest_and_select_partitions() {
    detect_partitions_handler || return 1

    echo "Selecting partitions..."
    ROOT_PART=$(select_partition_handler "root" "/tmp/root_candidates" | awk '{print $1}') || return 1
    BOOT_PART=$(select_partition_handler "boot" "/tmp/boot_candidates" | awk '{print $1}') || return 1
    BACKUP_PART=$(select_partition_handler "backup" "/tmp/backup_candidates" | awk '{print $1}') || return 1

    # Validate partition paths
    for part in "$ROOT_PART" "$BOOT_PART" "$BACKUP_PART"; do
        if [[ ! -e "$part" ]]; then
            echo "Error: Invalid partition path: $part"
            return 1
        fi
    done

    export ROOT_PART BOOT_PART BACKUP_PART

    echo -e "\nFinal Selections:"
    echo "ROOT_PART=$ROOT_PART"
    echo "BOOT_PART=$BOOT_PART" 
    echo "BACKUP_PART=$BACKUP_PART"

    return 0
}

# Select a partition with validation
select_partition_handler() {
    local prompt="$1"
    local candidates_file="$2"
    
    # Verify candidates file exists and is readable
    if [ ! -r "$candidates_file" ]; then
        echo "Error: Cannot read candidates file $candidates_file"
        return 1
    fi

    # Get default selection
    local default=$(head -n1 "$candidates_file")
    
    # Show available partitions
    suggest_partition_handler "$prompt" "$candidates_file" || return 1

    # Get user selection with validation
    while true; do
        read -p "Enter your choice for $prompt partition (or press Enter to use '$default'): " selected
        
        # Use default if empty input
        if [ -z "$selected" ]; then
            selected="$default"
            echo "Using default selection: $selected"
        fi

        # Validate selection exists in candidates
        if grep -q "^$selected$" "$candidates_file"; then
            # Additional validation that partition exists
            if [ -e "$selected" ]; then
                echo "Selected $prompt partition: $selected"
                echo "$selected"
                return 0
            else
                echo "Error: Partition $selected does not exist"
            fi
        else
            echo "Error: Invalid selection - must be one of:"
            cat "$candidates_file"
        fi
        
        echo "Please try again"
    done
}

# Clean up tree structure characters and format output
prepare_and_save_partition_candidates() {
    local candidates="$1"
    local output_file="$2"

    if [ -n "$candidates" ]; then
        clean_partitions "$candidates" | awk '{print $1}' > "$output_file"
    else
        echo "No valid candidates found."
    fi
}



# Suggest a partition to the user
suggest_partition_handler() {
    local prompt="$1"
    local candidates_file="$2"

    if [ ! -s "$candidates_file" ]; then
        echo "No valid $prompt candidates found."
        return 1
    fi

    echo "Available $prompt partitions:"
    cat "$candidates_file"
    echo ""

    local default=$(head -n1 "$candidates_file")
    echo "Suggested $prompt partition: $default"
    return 0
}


# List available USB devices with improved error handling
list_usb_devices_handler() {
    echo "Listing USB devices..."
    list_live_usb_devices_handler || { return 1; }
    list_backup_usb_devices_handler || { return 1; }
    checks_menu  # Zurück ins Menü nach Abschluss
}


# List available Backup USB devices
list_backup_usb_devices_handler() {
    echo "Listing Backup USB devices..."
    
    # Get USB devices using lsblk, excluding ISO filesystems
    local backup_usb_devices=$(lsblk -d -o NAME,TRAN,SIZE,MODEL,MOUNTPOINT,FSTYPE | grep usb | grep -v 'iso')
    
    echo "WARNING: Live USB systems should not be used as backup targets"
    
    if [ -z "$backup_usb_devices" ]; then
        echo "No USB devices found for backup"
        sleep 1.0
    fi
    
    echo "Available Backup USB devices:"
    echo "$backup_usb_devices"
    return 0
}

# List available Live USB devices
list_live_usb_devices_handler() {
    echo "Listing Live USB devices..."
    
    # Get USB devices using lsblk, including ISO filesystems
    local live_usb_devices=$(lsblk -d -o NAME,TRAN,SIZE,MODEL,MOUNTPOINT,FSTYPE | grep usb | grep 'iso')
    
    if [ -z "$live_usb_devices" ]; then
        echo "No Live USB devices found"
        sleep 1.0
    fi
    
    echo "Available Live USB devices:"
    echo "$live_usb_devices"
    return 0
}

# Verify system partitions
verify_partitions_handler() {
    echo "Verifying partitions..."
    
    # Check if root partition exists
    if [ ! -e "$ROOT_PART" ]; then
        echo "Error: Root partition $ROOT_PART not found"
        return 1
    fi
    
    # Check if boot partition exists (if specified)
    if [ -n "$BOOT_PART" ] && [ ! -e "$BOOT_PART" ]; then
        echo "Error: Boot partition $BOOT_PART not found"
        return 1
    fi
    
    echo "Partitions verified successfully"
    return 0
}

# Verify system requirements
verify_system_requirements_handler() {
    echo "Verifying system requirements..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo "Error: Script must be run as root"
        return 1
    fi
    
    # Check for required commands
    local required_commands=("lsblk" "mount" "umount" "chroot" "nixos-install")
    for cmd in "${required_commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            echo "Error: Required command '$cmd' not found"
            return 1
        fi
    done
    
    echo "System requirements verified"
    return 0
}

# Set up bind mounts for chroot
setup_bind_mounts_handler() {
    echo "Setting up bind mounts..."
    
    local required_mounts=("/proc" "/sys" "/dev" "/run")
    
    for mount_point in "${required_mounts[@]}"; do
        if [ -d "$mount_point" ]; then
            mkdir -p $MOUNT_DIR$mount_point
            mount --bind $mount_point $MOUNT_DIR$mount_point || { 
                echo "Failed to bind mount $mount_point"; 
                return 1
            }
        else
            echo "Warning: $mount_point does not exist"
        fi
    done
    
    echo "Bind mounts set up successfully"
    return 0
}

# Main bind mounts function
bind_mounts() {
    if ! setup_bind_mounts; then
        echo "Error: Failed to set up bind mounts"
        return 1
    fi
    return 0
}


# Save partition configuration
save_partition_config() {
    echo "ROOT_PART=$ROOT_PART" > /tmp/partition_config
    echo "BOOT_PART=$BOOT_PART" >> /tmp/partition_config
    echo "BACKUP_PART=$BACKUP_PART" >> /tmp/partition_config
}

# Load partition configuration
load_partition_config() {
    if [ -f /tmp/partition_config ]; then
        source /tmp/partition_config
        return 0
    fi
    return 1
}

# Simplified mount partitions handler
mount_partitions_handler() {
    echo "Setting up partition mounts..."
    
    # Create mount points
    mkdir -p /mnt /mnt/boot /mnt/backup || {
        echo "Error: Failed to create mount directories"
        return 1
    }

    # Mount root partition
    echo "Mounting root partition ($ROOT_PART) to /mnt"
    if ! sudo mount "$ROOT_PART" /mnt; then
        echo "Error: Failed to mount root partition"
        return 1
    fi

    # Mount boot partition
    echo "Mounting boot partition ($BOOT_PART) to /mnt/boot"
    if ! sudo mount "$BOOT_PART" /mnt/boot; then
        echo "Error: Failed to mount boot partition"
        sudo umount /mnt
        return 1
    fi

    # Mount backup partition
    echo "Mounting backup partition ($BACKUP_PART) to /mnt/backup"
    if ! sudo mount "$BACKUP_PART" /mnt/backup; then
        echo "Error: Failed to mount backup partition"
        sudo umount /mnt/boot
        sudo umount /mnt
        return 1
    fi

    echo "All partitions mounted successfully"
    return 0
}

# Enhanced mount checking and unmounting functions

# Unmount backup partition specifically
unmount_backup() {
    echo "Starting backup unmount process..."
    
    # Check if backup is mounted
    if ! findmnt -n -o TARGET "/mnt/backup" &>/dev/null; then
        echo "Backup partition is not mounted"
        return 0
    fi
    
    echo "Unmounting backup partition..."
    local errors=0
    
    if umount "/mnt/backup" 2>/dev/null; then
        echo "Successfully unmounted backup partition"
    else
        echo "Warning: Failed to unmount backup partition (retrying with lazy unmount)"
        umount -l "/mnt/backup" || {
            echo "Error: Could not unmount backup partition"
            ((errors++))
        }
    fi
    
    # Clean up backup mount directory
    if [[ -d "/mnt/backup" ]]; then
        echo "Cleaning up backup mount directory..."
        rmdir "/mnt/backup" || echo "Warning: Could not remove backup mount directory"
    fi
    
    if [[ $errors -gt 0 ]]; then
        echo "Backup unmount completed with $errors error(s)"
        return 1
    else
        echo "Backup unmount completed successfully"
        return 0
    fi
}

# Check if target directory is mounted with detailed status
is_mounted() {
    # Ensure MOUNT_DIR is available
    if [[ -z "$MOUNT_DIR" ]]; then
        echo "Error: MOUNT_DIR is not set"
        return 1
    fi
    
    # Get detailed mount info
    local mount_info=$(findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS "$MOUNT_DIR" 2>/dev/null)
    
    if [[ -n "$mount_info" ]]; then
        echo "Mount details for $MOUNT_DIR:"
        echo "$mount_info"
        return 0
    else
        echo "No active mounts found at $MOUNT_DIR"
        return 1
    fi
}

# Safely unmount all partitions and bind mounts with cleanup
unmount_all() {
    echo "Starting unmount process..."
    
    # Check if anything is mounted at MOUNT_DIR
    if ! is_mounted; then
        echo "No mounts to unmount at $MOUNT_DIR"
        return 0
    fi
    
    # Get all mount points under MOUNT_DIR in reverse order
    local mounted_points=($(findmnt -R -n -o TARGET "$MOUNT_DIR" | sort -r))
    
    if [[ ${#mounted_points[@]} -eq 0 ]]; then
        echo "No nested mounts found under $MOUNT_DIR"
    else
        echo "Found ${#mounted_points[@]} mounts to unmount:"
        printf ' - %s\n' "${mounted_points[@]}"
    fi
    
    # Unmount each point with error handling
    local errors=0
    for point in "${mounted_points[@]}"; do
        echo "Unmounting $point..."
        if umount "$point" 2>/dev/null; then
            echo "Successfully unmounted $point"
        else
            echo "Warning: Failed to unmount $point (retrying with lazy unmount)"
            umount -l "$point" || {
                echo "Error: Could not unmount $point"
                ((errors++))
            }
        fi
    done
    
    # Final check for remaining mounts
    if is_mounted; then
        echo "Warning: Some mounts could not be unmounted"
        ((errors++))
    else
        echo "All mounts successfully removed"
    fi
    
    # Clean up mount directory
    if [[ -d "$MOUNT_DIR" ]]; then
        echo "Cleaning up mount directory..."
        rmdir "$MOUNT_DIR" || echo "Warning: Could not remove mount directory"
    fi
    
    if [[ $errors -gt 0 ]]; then
        echo "Unmount completed with $errors error(s)"
        return 1
    else
        echo "Unmount completed successfully"
        return 0
    fi
}
