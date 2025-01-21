#!/bin/bash

# Main menu configuration
create_main_menu() {
    create_standard_menu "main" "NixOS Rescue Kit - Main Menu" \
        "Run Rescue" \
        "Open SSH" \
        "Extended Menus" \
        "Exit"
}


# Main extended_menu configuration
extended_menus_handler() {
    create_standard_menu "main" "NixOS Rescue Kit - Main Menu" \
        "Partition Management" \
        "Backup Management" \
        "System Repair" \
        "Rebuild System" \
        "SSH Management" \
        "Help" \
        "Exit"
}