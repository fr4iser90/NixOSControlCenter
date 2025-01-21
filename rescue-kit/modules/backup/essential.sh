#!/bin/bash

# Logging-Utility
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Backup wichtige System- und Benutzerdaten
backup_essential() {
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
