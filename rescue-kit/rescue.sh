#!/bin/bash
set -euo pipefail

# Define root directory
rescue_kit_root_dir="$(dirname "$(realpath "$0")")"

# Import variables and functions
source "$rescue_kit_root_dir/utils/variables.sh"
source "$rescue_kit_root_dir/utils/imports.sh"

# Import modules and utils
import_utils
import_modules

# Cleanup function
cleanup() {
    echo -e "\nCleaning up..."
    echo "Cleanup complete"
    exit 0
}

trap cleanup EXIT

# Import menu utilities
source "$rescue_kit_root_dir/utils/menu.sh"

# Initialize system
echo "Initializing NixOS Rescue Kit..."
echo "System ready. Loading main menu..."

# Create and start main menu
create_standard_menu "main" "NixOS Rescue Kit - Main Menu" \
    "System Checks" \
    "Partition Management" \
    "Backup Management" \
    "System Repair" \
    "Rebuild System" \
    "SSH Management" \
    "Help" \
    "Exit"

menu_loop
