#!/bin/bash

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
    
    if ! verify_partitions; then
        return 1
    fi
    
    if ! list_usb_devices; then
        return 1
    fi
    
    log "All checks completed successfully"
    return 0
}
