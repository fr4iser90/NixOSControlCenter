#!/usr/bin/env bash

# Am Anfang der Datei:
declare -g -A SUB_OPTIONS
declare -g -A MODULE_OPTIONS

# Neue Struktur für die Auswahl
INSTALL_TYPE_OPTIONS=(
    "Install a Predefined Profile"
    "Configure a Custom Setup"
)

PREDEFINED_PROFILE_OPTIONS=(
    "Fr4iser Personal Desktop"
    "Gira Personal Desktop"
    "Fr4iser Jetson Nano"
    "Homelab Server"
    "Hackathon Server"
)

# Hauptkategorien für Custom Setup
CUSTOM_BASE_MODES=(
    "Desktop"
    "Server"
)

# Feature-Optionen für Custom Setup (neue Struktur)
# Backward-Kompatibilität: Alte Namen funktionieren noch, werden intern gemappt
declare -A -g SUB_OPTIONS=(
    ["Desktop"]="None|streaming|emulation|web-dev|game-dev|python-dev|system-dev"
    ["Server"]="None|docker|docker-rootless|database|web-server|mail-server"
)

# Preset-Optionen (für Preset-Auswahl)
declare -a PRESET_OPTIONS=(
    "gaming-desktop"
    "dev-workstation"
    "homelab-server"
)

# Moduloptionen (veraltet, wird nicht mehr verwendet)
declare -A -g MODULE_OPTIONS=(
    ["Gaming Module"]="None|Streaming|Emulation"
    ["Development Module"]="None|Web|Game"
)

# Hilfsfunktionen für Name-Konvertierung
get_internal_name() {
    local display_name="$1"
    local options="$2"
    
    # Suche nach dem internen Namen im Format "internal:display"
    local IFS='|'
    for pair in $options; do
        local internal="${pair%%:*}"
        local display="${pair#*:}"
        if [[ "$display" == "$display_name" ]]; then
            echo "$internal"
            return 0
        fi
    done
    
    # Fallback: Lowercase und Bindestriche
    echo "${display_name,,}" | tr ' ' '-'
}

get_display_name() {
    local internal_name="$1"
    local options="$2"
    
    # Suche nach dem Display-Namen im Format "internal:display"
    local IFS='|'
    for pair in $options; do
        local internal="${pair%%:*}"
        local display="${pair#*:}"
        if [[ "$internal" == "$internal_name" ]]; then
            echo "$display"
            return 0
        fi
    done
    
    # Fallback: Erste Buchstaben groß
    echo "$internal_name" | sed 's/\b\(.\)/\u\1/g'
}

export -a INSTALL_TYPE_OPTIONS
export -a PREDEFINED_PROFILE_OPTIONS
export -a CUSTOM_BASE_MODES
export -a PRESET_OPTIONS
export -A SUB_OPTIONS
export -A MODULE_OPTIONS
export -f get_internal_name
export -f get_display_name
