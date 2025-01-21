#!/bin/bash

# Main menu configuration
create_main_menu() {
    create_standard_menu "main" "NixOS Rescue Kit - Main Menu" \
        "System Checks" \
        "Partition Management" \
        "Backup Management" \
        "System Repair" \
        "Rebuild System" \
        "SSH Management" \
        "Help" \
        "Exit"
}


