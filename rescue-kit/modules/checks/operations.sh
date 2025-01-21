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


# Detect and suggest partitions
detect_partitions_handler() {
    echo "Detecting partitions..."
    local partitions=$(lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT -p -n)

    if [ -z "$partitions" ]; then
        echo "Error: No partitions found."
        return 1
    fi

    echo "Detected partitions:"
    echo "$partitions"
    echo ""

    # Suggest root and boot partitions
    local root_candidates=$(echo "$partitions" | grep -E 'ext4|xfs|btrfs')
    local boot_candidates=$(echo "$partitions" | grep -E 'vfat|fat32' | grep -v 'usb')

    echo "Suggested root partitions:"
    echo "$root_candidates"
    echo ""

    if [ -n "$boot_candidates" ]; then
        echo "Suggested boot partitions:"
        echo "$boot_candidates"
    else
        echo "No boot partition candidates found."
    fi

    # Prompt user for confirmation or manual input
    echo ""
    read -p "Use detected suggestions? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        ROOT_PART=$(echo "$root_candidates" | head -n1 | awk '{print $1}')
        BOOT_PART=$(echo "$boot_candidates" | head -n1 | awk '{print $1}')
        echo "Using detected partitions:"
        echo "Root: $ROOT_PART"
        echo "Boot: $BOOT_PART"
    else
        read -p "Enter root partition (e.g., /dev/sda1): " ROOT_PART
        read -p "Enter boot partition (e.g., /dev/sda2) [optional]: " BOOT_PART
        echo "Using manually configured partitions:"
        echo "Root: $ROOT_PART"
        echo "Boot: $BOOT_PART"
    fi

    export ROOT_PART
    export BOOT_PART
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