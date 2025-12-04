#!/usr/bin/env bash

# Am Anfang der Datei:
declare -g -A SUB_OPTIONS
declare -g -A MODULE_OPTIONS

# Neue Struktur für die Auswahl
INSTALL_TYPE_OPTIONS=(
    "📦 Presets"
    "🔧 Custom Install"
    "⚙️  Advanced Options"
)

# System Presets (öffentliche, wiederverwendbare Konfigurationen)
SYSTEM_PRESETS=(
    "Desktop"
    "Server"
    "Homelab Server"
)

# Device Presets (geräte-spezifische Konfigurationen)
DEVICE_PRESETS=(
    "Jetson Nano"
)

# Advanced Options
ADVANCED_OPTIONS=(
    "📁 Load Profile from File"
    "📋 Show Available Profiles"
    "🔄 Import from Existing Config"
)

# Legacy: Für Backward Compatibility (wird nicht mehr in UI angezeigt)
PREDEFINED_SERVER_PROFILES=(
    "Homelab Server"
    "Fr4iser Jetson Nano"
)

# Desktop Profile (persönliche Profile entfernt - jetzt in Advanced Options)
PREDEFINED_DESKTOP_PROFILES=(
)

# Combined for backward compatibility
PREDEFINED_PROFILE_OPTIONS=(
    "${PREDEFINED_SERVER_PROFILES[@]}"
    "${PREDEFINED_DESKTOP_PROFILES[@]}"
)

# Alle Features (16 Features: 3 Desktop-Envs + 13 Package Features)
ALL_FEATURES=(
    # Desktop Environments
    "plasma" "gnome" "xfce"
    # Development
    "web-dev" "game-dev" "python-dev" "system-dev"
    # Gaming & Media
    "streaming" "emulation"
    # Containerization
    "docker" "docker-rootless" "podman"
    # Services
    "database" "web-server" "mail-server"
    # Virtualization
    "qemu-vm" "virt-manager"
)

# Feature-Gruppen für UI
FEATURE_GROUPS=(
    "🖥️  Desktop Environment:plasma|gnome|xfce"
    "📦 Development:web-dev|game-dev|python-dev|system-dev"
    "🎮 Gaming & Media:streaming|emulation"
    "🐳 Containerization:docker|docker-rootless|podman"
    "💾 Services:database|web-server|mail-server"
    "🖥️  Virtualization:qemu-vm|virt-manager"
)

# Exklusive Gruppen (nur eins auswählbar)
declare -A -g EXCLUSIVE_GROUPS=(
    ["desktop-environment"]="plasma|gnome|xfce"
    ["containerization"]="docker|docker-rootless|podman"
)

# Dependencies (automatisch hinzufügen)
declare -A -g FEATURE_DEPENDENCIES=(
    ["virt-manager"]="qemu-vm"
)

# Conflicts (automatisch abwählen)
declare -A -g FEATURE_CONFLICTS=(
    ["docker"]="docker-rootless|podman"
    ["docker-rootless"]="docker|podman"
    ["podman"]="docker|docker-rootless"
    ["plasma"]="gnome|xfce"
    ["gnome"]="plasma|xfce"
    ["xfce"]="plasma|gnome"
)

# Legacy: Für Backward Compatibility (wird nicht mehr in UI angezeigt)
declare -A -g SUB_OPTIONS=(
    ["Desktop"]="None|streaming|emulation|web-dev|game-dev|python-dev|system-dev|docker|docker-rootless|database|web-server"
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

# Helper function to check if profile is disabled
is_profile_disabled() {
    local profile="$1"
    [[ "$profile" == *"(disabled)"* ]]
}

export -a INSTALL_TYPE_OPTIONS
export -a SYSTEM_PRESETS
export -a DEVICE_PRESETS
export -a ADVANCED_OPTIONS
export -a PREDEFINED_PROFILE_OPTIONS
export -a PREDEFINED_SERVER_PROFILES
export -a PREDEFINED_DESKTOP_PROFILES
export -a ALL_FEATURES
export -a FEATURE_GROUPS
export -a PRESET_OPTIONS
export -A SUB_OPTIONS
export -A MODULE_OPTIONS
export -A EXCLUSIVE_GROUPS
export -A FEATURE_DEPENDENCIES
export -A FEATURE_CONFLICTS
export -f get_internal_name
export -f get_display_name
export -f is_profile_disabled
