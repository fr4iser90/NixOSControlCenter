#!/bin/bash

# Run all checks
run_all_checks() {
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
