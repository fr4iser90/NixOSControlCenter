#!/usr/bin/env bash

# Prüfe ob wir root sind
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        error "Please run as root"
        exit 1
    fi
}

# Verzeichnis erstellen wenn es nicht existiert
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        info "Created directory: $dir"
    fi
}

# Backup einer Datei erstellen
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        info "Created backup of $file"
    fi
}