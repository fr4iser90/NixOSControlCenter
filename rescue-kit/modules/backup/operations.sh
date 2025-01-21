#!/bin/bash

# Logging-Utility
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Backup wichtige System- und Benutzerdaten
backup_essential_handler() {
    local backup_dir=$1
    local max_size=32000000  # Maximale Größe in Kilobyte (32GB)

    log "Starte die Sicherung wichtiger Daten nach $backup_dir..."

    # Sicherungsverzeichnis erstellen
    mkdir -p "$backup_dir" || {
        log "Fehler: Sicherungsverzeichnis konnte nicht erstellt werden"
        return 1
    }

    # Wichtige Verzeichnisse für die Sicherung
    local essential_dirs=(
        "/etc/nixos"
        "/etc/ssh"
        "/home/$USER/Documents"
    )

    # Überprüfen, ob benutzerdefinierte Verzeichnisse hinzugefügt wurden
    if [ -n "$2" ]; then
        IFS=' ' read -r -a custom_dirs <<< "$2"
        essential_dirs+=("${custom_dirs[@]}")
    fi

    # Sicherung jedes Verzeichnisses
    local total_size=0
    for dir in "${essential_dirs[@]}"; do
        if [ -d "$MOUNT_DIR$dir" ]; then
            log "Backup von $dir..."
            local dir_size=$(du -sk "$MOUNT_DIR$dir" | cut -f1)
            if [ $((total_size + dir_size)) -le $max_size ]; then
                rsync -a --relative "$MOUNT_DIR$dir" "$backup_dir" || {
                    log "Fehler: Backup von $dir fehlgeschlagen"
                    return 1
                }
                total_size=$((total_size + dir_size))
            else
                log "Überspringe $dir wegen Platzbeschränkungen"
            fi
        fi
    done

    log "Wichtige Daten-Sicherung abgeschlossen"
    return 0
}


# Full system backup
backup_full_handler() {
    local backup_dir=$1
    log "Starting full system backup to $backup_dir..."
    
    # Create backup directory
    mkdir -p $backup_dir || {
        log "Error: Failed to create backup directory"
        return 1
    }
    
    # Exclude directories
    local exclude=(
        "--exclude=/proc"
        "--exclude=/sys"
        "--exclude=/dev"
        "--exclude=/run"
        "--exclude=/tmp"
        "--exclude=$backup_dir"
    )
    
    # Perform backup
    rsync -a "${exclude[@]}" "$MOUNT_DIR/" "$backup_dir" || {
        log "Error: Full system backup failed"
        return 1
    }
    
    log "Full system backup completed"
    return 0
}


# Verify backup integrity
verify_backup_handler() {
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


display_backup_dir_status_handler() {
    return 0
}