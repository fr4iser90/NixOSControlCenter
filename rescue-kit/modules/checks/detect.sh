#!/bin/bash

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
    
    # Find potential boot partitions (excluding USB devices)
    local boot_candidates=$(lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,TRAN -p -n | grep -E 'vfat|fat32' | grep -v 'usb')
    
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
