#!/bin/bash

# This script should be sourced from rescue.sh, not run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This script is designed to be sourced from rescue.sh"
    echo "Please run the main rescue script instead:"
    echo "  sudo ./rescue.sh"
    exit 1
fi

# Detect and suggest partitions
detect_partitions() {
    log "Detecting partitions..."
    
    # Get all partitions using lsblk
    local partitions=$(lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT -p -n)
    
    if [ -z "$partitions" ]; then
        log "Error: No partitions found"
        return 1
    fi
    
    echo "Detected partitions:"
    echo "$partitions"
    echo ""
    
    # Find potential root partitions
    local root_candidates=$(echo "$partitions" | grep -E 'ext4|xfs|btrfs')
    if [ -z "$root_candidates" ]; then
        log "Error: No suitable root partition candidates found"
        return 1
    fi
    
    # Find potential boot partitions
    local boot_candidates=$(echo "$partitions" | grep -E 'vfat|fat32')
    
    # Suggest partitions
    echo "Suggested root partitions:"
    echo "$root_candidates"
    echo ""
    
    if [ -n "$boot_candidates" ]; then
        echo "Suggested boot partitions:"
        echo "$boot_candidates"
    else
        echo "No boot partition candidates found"
    fi
    
    # Prompt for confirmation
    echo ""
    read -p "Do you want to use these suggestions? (y/n) " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Set first root candidate
        ROOT_PART=$(echo "$root_candidates" | head -n1 | awk '{print $1}')
        
        # Set first boot candidate if available
        if [ -n "$boot_candidates" ]; then
            BOOT_PART=$(echo "$boot_candidates" | head -n1 | awk '{print $1}')
        else
            BOOT_PART=""
        fi
        
        log "Using detected partitions:"
        log "Root: $ROOT_PART"
        log "Boot: $BOOT_PART"
        return 0
    else
        log "Using manually configured partitions"
        return 0
    fi
}

# Verify system partitions
verify_partitions() {
    log "Verifying partitions..."
    
    # Check if root partition exists
    if [ ! -e "$ROOT_PART" ]; then
        log "Error: Root partition $ROOT_PART not found"
        return 1
    fi
    
    # Check if boot partition exists (if specified)
    if [ -n "$BOOT_PART" ] && [ ! -e "$BOOT_PART" ]; then
        log "Error: Boot partition $BOOT_PART not found"
        return 1
    fi
    
    log "Partitions verified successfully"
    return 0
}

# List available USB devices
list_usb_devices() {
    log "Listing USB devices..."
    
    # Get USB devices using lsblk
    local usb_devices=$(lsblk -d -o NAME,TRAN,SIZE,MODEL | grep usb)
    
    if [ -z "$usb_devices" ]; then
        log "No USB devices found"
        return 1
    fi
    
    echo "Available USB devices:"
    echo "$usb_devices"
    return 0
}

# Verify system requirements
verify_system() {
    log "Verifying system requirements..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log "Error: Script must be run as root"
        return 1
    fi
    
    # Check for required commands
    local required_commands=("lsblk" "mount" "umount" "chroot" "nixos-install")
    for cmd in "${required_commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            log "Error: Required command '$cmd' not found"
            return 1
        fi
    done
    
    log "System requirements verified"
    return 0
}

# Run all checks
run_checks() {
    log "Running system checks..."
    
    if ! verify_system; then
        return 1
    fi
    
    if ! detect_partitions; then
        return 1
    fi
    
    if ! verify_partitions; then
        return 1
    fi
    
    if ! list_usb_devices; then
        return 1
    fi
    
    log "All checks completed successfully"
    return 0
}
