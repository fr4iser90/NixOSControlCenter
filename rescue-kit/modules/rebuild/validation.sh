#!/bin/bash

# Validate NixOS configuration
validate_configuration() {
    log "Validating NixOS configuration..."
    
    if ! nixos-container --root $MOUNT_DIR run -- nixos-rebuild dry-build; then
        log "Error: NixOS configuration validation failed"
        return 1
    fi
    
    log "Configuration validated successfully"
    return 0
}
