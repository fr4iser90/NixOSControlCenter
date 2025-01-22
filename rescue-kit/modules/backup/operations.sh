#!/bin/bash

# Backup wichtige System- und Benutzerdaten
backup_essential_handler() {
    local username="fr4iser"  # Benutzername als dynamischer Placeholder
    local backup_dir="/mnt/backup"  # Fester Pfad für das Backup-Verzeichnis
    local max_size=32000000  # Maximale Größe in Kilobyte (32GB)

    echo "Starte die Sicherung wichtiger Daten nach $backup_dir..."

    # Überprüfen ob root gemountet ist
    if mountpoint -q /mnt/root; then
        local root_dir="/mnt/root"
    else
        echo "Fehler: Root Partition ist nicht gemountet."
        return 1
    fi

    # Wichtige Verzeichnisse für die Sicherung
    local essential_dirs=(
        "$root_dir/etc/nixos"
        "$root_dir/etc/ssh"
        "$root_dir/home/$username/Documents"
    )

    # Sicherung jedes Verzeichnisses
    local total_size=0
    for dir in "${essential_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo "Backup von $dir..."
            local dir_size=$(du -sk "$dir" | cut -f1)
            if [ $((total_size + dir_size)) -le $max_size ]; then
                rsync -a --relative "$dir" "$backup_dir" || {
                    echo "Fehler: Backup von $dir fehlgeschlagen"
                    return 1
                }
                total_size=$((total_size + dir_size))
            else
                echo "Überspringe $dir wegen Platzbeschränkungen"
            fi
        fi
    done

    echo "Wichtige Daten-Sicherung abgeschlossen"
    sleep 5
    return 0
}

# Full system backup
backup_full_handler() {
    local backup_dir=$1
    echo "Starting full system backup to $backup_dir..."
    
    # Create backup directory
    mkdir -p $backup_dir || {
        echo "Error: Failed to create backup directory"
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
        echo "Error: Full system backup failed"
        return 1
    }
    
    echo "Full system backup completed"
    return 0
}


# Verify backup integrity
verify_backup_handler() {
    local backup_dir=$1
    echo "Verifying backup integrity..."
    
    # Check backup directory exists
    if [ ! -d "$backup_dir" ]; then
        echo "Error: Backup directory not found"
        return 1
    fi
    
    # Verify NixOS configuration
    if [ ! -f "$backup_dir/etc/nixos/configuration.nix" ] && 
       [ ! -f "$backup_dir/etc/nixos/flake.nix" ]; then
        echo "Error: No NixOS configuration found (configuration.nix or flake.nix)"
        return 1
    fi
    
    # Check for secrets directory if it exists in source
    if [ -d "/etc/nixos/secrets" ]; then
        if [ ! -d "$backup_dir/etc/nixos/secrets" ]; then
            echo "Error: Secrets directory missing in backup"
            return 1
        fi
        
        # Verify at least one secret file exists
        if [ -z "$(ls -A $backup_dir/etc/nixos/secrets)" ]; then
            echo "Error: Secrets directory is empty"
            return 1
        fi
    fi
    
    echo "Backup verification successful"
    return 0
}


display_backup_dir_status_handler() {
    return 0
}