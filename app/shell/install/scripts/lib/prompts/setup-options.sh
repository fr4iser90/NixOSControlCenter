#!/usr/bin/env bash

# Hauptkategorien
MAIN_OPTIONS=(
    "Desktop"
    "Server"
    "HomelabServer"
)

# Unterkategorien
declare -A SUB_OPTIONS=(
    ["Desktop"]="No Modules|Gaming|Gaming-Streaming|Gaming-Emulation|Development|Development-Web|Development-Game"
    ["Server"]="No Modules|Docker|Database"
)

# Module pro Unterkategorie
declare -A MODULE_OPTIONS=(
    ["Gaming Module"]="No Modules|Streaming|Emulation"
    ["Development Module"]="No Modules|Web|Game"
)

# Verfügbare Optionen
SETUP_OPTIONS=(
    "Desktop"
    "Server"
    "HomelabServer"
    "Custom Setup"
    "Gaming"
    "Gaming-Streaming"
    "Gaming-Emulation"
    "Development"
    "Development-Web"
    "Development-Game"
    "Docker"
    "Database"
)

export MAIN_OPTIONS
export SUB_OPTIONS
export MODULE_OPTIONS
export SETUP_OPTIONS