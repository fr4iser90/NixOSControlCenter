#!/usr/bin/env bash

# Setup-Modelle definieren
declare -A SETUP_MODELS=(
    ["Desktop (Basic)"]="Simple desktop setup with GUI"
    ["Server (Basic)"]="Minimal server installation"
    ["Gaming"]="Gaming optimized setup with Steam"
    ["Development"]="Development environment with common tools"
    ["Gaming + Dev"]="Combined gaming and development setup"
    ["Homelab Server"]="Homelab server setup"
    ["Custom Setup"]="Build your own configuration"
)

# Definiere die Reihenfolge
SETUP_ORDER=(
    "Desktop (Basic)"
    "Server (Basic)"
    "Gaming"
    "Development"
    "Gaming + Dev"
    "Homelab Server"
    "Custom Setup"
)

select_setup_mode() {
    printf "%s\n" "${SETUP_ORDER[@]}" | fzf \
        --header="Select Setup Mode" \
        --preview 'echo "${SETUP_MODELS[$1]}"' \
        --prompt="Setup > "
}