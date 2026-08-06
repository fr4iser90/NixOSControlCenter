#!/usr/bin/env bash

# Am Anfang der Datei:
declare -g -A SUB_OPTIONS
declare -g -A MODULE_OPTIONS

# Neue Struktur für die Auswahl
INSTALL_TYPE_OPTIONS=(
    "📦 Presets"
    "⚙️ Advanced Options"
)

# System Presets (öffentliche, wiederverwendbare Konfigurationen)
# Each preset is customizable: after pick → optional extra packages (defaults below).
SYSTEM_PRESETS=(
    "Desktop"
    "Server"
    "Homelab Server"
    "From Scratch"
)

# Device Presets (geräte-spezifische Konfigurationen)
DEVICE_PRESETS=(
    "Jetson Nano"
)

# Default package modules per preset (space-separated). Applied unless user removes them in GUI.
# From Scratch / empty = no defaults (user picks everything).
declare -A -g PRESET_DEFAULT_PACKAGES=(
    ["Desktop"]=""
    ["Server"]=""
    ["Homelab Server"]="docker database web-server"
    ["From Scratch"]=""
    ["Jetson Nano"]=""
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

# Alle Features (17 Features: 3 Desktop-Envs + 14 Package Features)
ALL_FEATURES=(
    # Desktop Environments
    "plasma" "gnome" "xfce"
    # Development
    "web-dev" "game-dev" "python-dev" "system-dev"
    # Gaming & Media
    "gaming" "streaming" "emulation"
    # Containerization
    "docker" "podman"
    # Services
    "database" "web-server" "mail-server"
    # Virtualization
    "qemu-vm" "virt-manager"
)

# Feature-Gruppen für UI (ohne Emojis - werden als Präfix verwendet)
FEATURE_GROUPS=(
    "Desktop Environment:plasma|gnome|xfce"
    "Development:web-dev|game-dev|python-dev|system-dev"
    "Gaming & Media:gaming|streaming|emulation"
    "Containerization:docker|podman"
    "Services:database|web-server|mail-server"
    "Virtualization:qemu-vm|virt-manager"
)

# Exklusive Gruppen (nur eins auswählbar)
declare -A -g EXCLUSIVE_GROUPS=(
    ["desktop-environment"]="plasma|gnome|xfce"
    ["containerization"]="docker|podman"
)

# Dependencies (automatisch hinzufügen)
declare -A -g FEATURE_DEPENDENCIES=(
    ["virt-manager"]="qemu-vm"
)

# Conflicts (automatisch abwählen)
declare -A -g FEATURE_CONFLICTS=(
    ["docker"]="podman"
    ["podman"]="docker"
    ["plasma"]="gnome|xfce"
    ["gnome"]="plasma|xfce"
    ["xfce"]="plasma|gnome"
)

# Desktop browser picker (SSOT) — format: "nixpkgsAttr|UI label"
# First entry is the default checked browser. Add more lines as needed.
DESKTOP_BROWSERS=(
    "firefox|Firefox — default, free"
    "chromium|Chromium — open-source Chrome"
    "brave|Brave — privacy Chromium (unfree)"
    "librewolf|LibreWolf — privacy Firefox fork"
)
DESKTOP_BROWSER_DEFAULT="firefox"

# Legacy: Für Backward Compatibility (wird nicht mehr in UI angezeigt)
declare -A -g SUB_OPTIONS=(
    ["Desktop"]="None|gaming|streaming|emulation|web-dev|game-dev|python-dev|system-dev|docker|database|web-server"
    ["Server"]="None|docker|database|web-server|mail-server"
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
export -A PRESET_DEFAULT_PACKAGES
export -f get_internal_name
export -f get_display_name
export -f is_profile_disabled
