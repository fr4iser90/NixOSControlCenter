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

# Hauptkategorien für Custom Setup (vorher MAIN_OPTIONS)
CUSTOM_BASE_MODES=(
    "Desktop"
    "Server"
)

# Unterkategorien direkt mit Display-Namen (bleibt gleich für Custom Setup)
declare -A -g SUB_OPTIONS=(
    ["Desktop"]="None|Gaming-Streaming|Gaming-Emulation|Development-Web|Development-Game"
    ["Server"]="None|Docker|Database"
)

# Moduloptionen (bleibt gleich für Custom Setup)
declare -A -g MODULE_OPTIONS=(
    ["Gaming Module"]="None|Streaming|Emulation"
    ["Development Module"]="None|Web|Game"
)

# Verfügbare Optionen (Display-Namen) - DIESE LISTE MUSS ÜBERARBEITET ODER ENTFERNT WERDEN
# Da die Logik sich ändert, ist eine flache Liste aller Optionen ggf. nicht mehr sinnvoll
# SETUP_OPTIONS=(
#     "Desktop"
#     "Server"
#     "HomelabServer"
#     "HackathonServer"
# "Custom Setup" # Dieser Begriff wird jetzt anders verwendet
#     "Gaming-Streaming"
#     "Gaming-Emulation"
#     "Development-Web"
#     "Development-Game"
#     "Docker"
#     "Database"
# )

# Hilfsfunktionen für Name-Konvertierung (bleiben bestehen)
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
export -a CUSTOM_BASE_MODES # Vorher MAIN_OPTIONS
export -A SUB_OPTIONS
export -A MODULE_OPTIONS
# export -a SETUP_OPTIONS # Auskommentiert, da überarbeitet werden muss
export -f get_internal_name
export -f get_display_name