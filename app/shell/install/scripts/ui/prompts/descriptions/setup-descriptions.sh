#!/usr/bin/env bash

# Definiere die Beschreibungen
declare -A SETUP_DESCRIPTIONS=(
    ["None"]="Basic system without additional modules"
    ["Desktop"]="A graphical desktop environment"
    ["Gaming"]="Gaming optimized additions"
    ["Gaming-Streaming"]="Streaming tools and features"
    ["Gaming-Emulation"]="Retro gaming support"
    ["Development"]="Development environment"
    ["Development-Web"]="Web development stack"
    ["Development-Game"]="Game development tools"
    ["Development-Virtualization"]="Virtual Machine|Virtualization Tools|GPU Support"
    ["Server"]="Headless server setup"
    ["Docker"]="Container support"
    ["Database"]="Database servers"
    ["HomelabServer"]="Pre-configured homelab"
    ["Custom Setup"]="Custom configuration"
)

declare -A SETUP_FEATURES=(
    ["None"]="Basic System|Minimal Installation|Core Utilities"
    ["Desktop"]="GUI Environment|Basic Applications|Sound Support|Network Manager"
    ["Gaming"]="Steam|Gamemode|Gaming Drivers|Performance Tools"
    ["Gaming-Streaming"]="OBS Studio|Discord|Streaming Optimizations"
    ["Gaming-Emulation"]="RetroArch|Common Emulators|Controller Support"
    ["Development"]="VS Code|Git|Build Tools|Development Libraries"
    ["Development-Web"]="Node.js|Web Servers|Database Tools"
    ["Development-Game"]="Game Engines|Asset Tools|Debug Tools"
    ["Development-Virtualization"]="Virtual Machine|Virtualization Tools|GPU Support"
    ["Server"]="CLI Only|Server Optimizations|Remote Management"
    ["Docker"]="Docker Engine|Docker Compose|Container Tools"
    ["Database"]="PostgreSQL|MySQL|Redis"
    ["HomelabServer"]="Media Server|Network Services|Storage Management"
    ["Custom Setup"]="Full Control|Manual Setup|Advanced Options"
)

declare -A SETUP_TYPES=(
    ["None"]="BASIC SYSTEM"
    ["Desktop"]="DESKTOP SYSTEM"
    ["Server"]="SERVER SYSTEM"
    ["HomelabServer"]="HOMELAB SERVER"
    ["Custom Setup"]="CUSTOM SETUP"
    ["Gaming"]="DESKTOP SYSTEM"
    ["Gaming-Streaming"]="DESKTOP SYSTEM"
    ["Gaming-Emulation"]="DESKTOP SYSTEM"
    ["Development"]="DESKTOP SYSTEM"
    ["Development-Web"]="DESKTOP SYSTEM"
    ["Development-Game"]="DESKTOP SYSTEM"
    ["Development-Virtualization"]="DESKTOP SYSTEM"
    ["Docker"]="SERVER SYSTEM"
    ["Database"]="SERVER SYSTEM"
)

get_description() {
    echo "${SETUP_DESCRIPTIONS[$1]:-No description available}"
}

get_features() {
    echo "${SETUP_FEATURES[$1]:-}"
}

get_type() {
    echo "${SETUP_TYPES[$1]:-CUSTOM SETUP}"
}

# Exportiere die Funktionen und Arrays
export -f get_description
export -f get_features
export -f get_type
export SETUP_DESCRIPTIONS
export SETUP_FEATURES
export SETUP_TYPES