#!/bin/bash

# Verify backup integrity
verify_backup() {
    local backup_dir=$1
    log "Verifying backup integrity..."
    
    # Check backup directory exists
    if [ ! -d "$backup_dir" ]; then
        log "Error: Backup directory not found"
        return 1
    fi
    
    # Verify NixOS configuration
    if [ ! -f "$backup_dir/etc/nixos/configuration.nix" ] && 
       [ ! -f "$backup_dir/etc/nixos/flake.nix" ]; then
        log "Error: No NixOS configuration found (configuration.nix or flake.nix)"
        return 1
    fi
    
    # Check for secrets directory if it exists in source
    if [ -d "/etc/nixos/secrets" ]; then
        if [ ! -d "$backup_dir/etc/nixos/secrets" ]; then
            log "Error: Secrets directory missing in backup"
            return 1
        fi
        
        # Verify at least one secret file exists
        if [ -z "$(ls -A $backup_dir/etc/nixos/secrets)" ]; then
            log "Error: Secrets directory is empty"
            return 1
        fi
    fi
    
    log "Backup verification successful"
    return 0
}
