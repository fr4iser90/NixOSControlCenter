#!/bin/bash

# List available USB devices
list_usb_devices() {
    log "Listing USB devices..."
    
    # Get USB devices using lsblk, excluding ISO filesystems
    local usb_devices=$(lsblk -d -o NAME,TRAN,SIZE,MODEL,MOUNTPOINT,FSTYPE | grep usb | grep -v 'iso')
    
    echo "WARNING: Live USB systems should not be used as backup targets"
    
    if [ -z "$usb_devices" ]; then
        log "No USB devices found"
        return 1
    fi
    
    echo "Available USB devices:"
    echo "$usb_devices"
    return 0
}
