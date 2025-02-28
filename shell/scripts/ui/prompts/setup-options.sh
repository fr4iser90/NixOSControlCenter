#!/usr/bin/env bash

# Am Anfang der Datei:
declare -g -A SUB_OPTIONS
declare -g -A MODULE_OPTIONS

# Hauptkategorien
MAIN_OPTIONS=(
    "Desktop"
    "Server"
    "HomelabServer"
)

# Unterkategorien direkt mit Display-Namen
declare -A -g SUB_OPTIONS=(
    ["Desktop"]="None|Gaming-Streaming|Gaming-Emulation|Development-Web|Development-Game"
    ["Server"]="None|Docker|Database"
)


declare -A -g MODULE_OPTIONS=(
    ["Gaming Module"]="None|Streaming|Emulation"
    ["Development Module"]="None|Web|Game"
)

# Verfügbare Optionen (Display-Namen)
SETUP_OPTIONS=(
    "Desktop"
    "Server"
    "HomelabServer"
    "Custom Setup"
    "Gaming-Streaming"
    "Gaming-Emulation"
    "Development-Web"
    "Development-Game"
    "Docker"
    "Database"
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

export -a MAIN_OPTIONS     # Liste
export -A SUB_OPTIONS      # Zuordnung
export -A MODULE_OPTIONS   # Zuordnung
export -a SETUP_OPTIONS    # Liste
export -f get_internal_name
export -f get_display_name