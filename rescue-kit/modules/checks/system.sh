#!/bin/bash

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
