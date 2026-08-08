#!/usr/bin/env bash

# Am Anfang der Datei:
declare -g -A SUB_OPTIONS
declare -g -A MODULE_OPTIONS

# Neue Struktur für die Auswahl
INSTALL_TYPE_OPTIONS=(
    "📦 Install bases"
    "⚙️ Advanced Options"
)

# Install bases (Desktop/Server starters) — NOT package recipes/sets
INSTALL_BASES=(
    "Desktop"
    "Server"
    "Homelab Server"
    "From Scratch"
)

# Device targets (hardware-specific install starters)
DEVICE_TARGETS=(
    "Jetson Nano"
)

# Default package modules per install base (space-separated).
declare -A -g INSTALL_BASE_DEFAULT_PACKAGES=(
    ["Desktop"]=""
    ["Server"]=""
    ["Homelab Server"]="docker database web-server"
    ["From Scratch"]=""
    ["Jetson Nano"]=""
)

# Advanced Options
ADVANCED_OPTIONS=(
    "📁 Load host blueprint from file"
    "📋 Show available host blueprints"
    "🔄 Import from Existing Config"
)

# Legacy lists (compat)
LEGACY_SERVER_BLUEPRINTS=(
    "Homelab Server"
    "Fr4iser Jetson Nano"
)

LEGACY_DESKTOP_BLUEPRINTS=(
)

LEGACY_BLUEPRINT_OPTIONS=(
    "${LEGACY_SERVER_BLUEPRINTS[@]}"
    "${LEGACY_DESKTOP_BLUEPRINTS[@]}"
)

# Alle Features (17 Features: 3 Desktop-Envs + 14 Package Features)
ALL_FEATURES=(
    # Desktop Environments
    "plasma" "gnome" "xfce"
    # Development
    "web-dev" "game-engines" "python-dev" "system-dev"
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
    "Development:web-dev|game-engines|python-dev|system-dev"
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
    ["Desktop"]="None|gaming|streaming|emulation|web-dev|game-engines|python-dev|system-dev|docker|database|web-server"
    ["Server"]="None|docker|database|web-server|mail-server"
)

# Package recipes (packages/components/recipes/) — NOT install bases
declare -a PACKAGE_RECIPE_OPTIONS=(
    "gaming-desktop"
    "dev-lean"
    "virt-desktop"
    "homelab-server"
    "dev-workstation"
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

# Populate FEATURE_SYSTEM_TYPES from packages metadata (SSOT for desktop|server filter)
load_feature_system_types() {
    declare -gA FEATURE_SYSTEM_TYPES=()
    local repo_root meta json line key val
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
    meta="$repo_root/nixos/core/base/packages/lib/metadata.nix"
    [[ -f "$meta" ]] || return 0
    command -v nix-instantiate >/dev/null 2>&1 || return 0
    command -v jq >/dev/null 2>&1 || return 0
    json=$(nix-instantiate --eval --strict --json -E "
      let
        lib = (import <nixpkgs> {}).lib;
        m = import $meta;
      in
        lib.mapAttrs (n: v: v.systemTypes or []) m.modules
    " 2>/dev/null) || return 0
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      key="${line%%=*}"
      val="${line#*=}"
      FEATURE_SYSTEM_TYPES["$key"]="$val"
    done < <(echo "$json" | jq -r 'to_entries[] | "\(.key)=\(.value|join("|"))"')
}

feature_allowed_for_system() {
    local feat="$1" st="$2"
    local types="${FEATURE_SYSTEM_TYPES[$feat]:-}"
    [[ -z "$types" ]] && return 0
    local t
    IFS='|' read -ra _types <<< "$types"
    for t in "${_types[@]}"; do
        [[ "$t" == "$st" ]] && return 0
    done
    return 1
}

export -a INSTALL_TYPE_OPTIONS
export -a INSTALL_BASES
export -a DEVICE_TARGETS
export -a ADVANCED_OPTIONS
export -a LEGACY_BLUEPRINT_OPTIONS
export -a LEGACY_SERVER_BLUEPRINTS
export -a LEGACY_DESKTOP_BLUEPRINTS
export -a ALL_FEATURES
export -a FEATURE_GROUPS
export -a PACKAGE_RECIPE_OPTIONS
export -A SUB_OPTIONS
export -A MODULE_OPTIONS
export -A EXCLUSIVE_GROUPS
export -A FEATURE_DEPENDENCIES
export -A FEATURE_CONFLICTS
export -A INSTALL_BASE_DEFAULT_PACKAGES
export -A FEATURE_SYSTEM_TYPES
export -f get_internal_name
export -f get_display_name
export -f is_profile_disabled
export -f load_feature_system_types
export -f feature_allowed_for_system
