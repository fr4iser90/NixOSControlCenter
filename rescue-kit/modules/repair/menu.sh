#!/bin/bash

# Repair menu
repair_menu() {
    while true; do
        clear
        display_header "System Repair"
        display_menu_options \
            "Run Filesystem Check" \
            "Fix Broken Packages" \
            "Repair Bootloader" \
            "Check System Integrity" \
            "Back to Main Menu"
        
        choice=$(prompt_menu_selection)
        
        case $choice in
            1)
                if confirm_action "Run filesystem check?"; then
                    run_fsck
                fi
                ;;
            2)
                if confirm_action "Fix broken packages?"; then
                    fix_broken_packages
                fi
                ;;
            3)
                if confirm_action "Repair bootloader?"; then
                    repair_bootloader
                fi
                ;;
            4)
                if confirm_action "Check system integrity?"; then
                    check_system_integrity
                fi
                ;;
            5)
                break
                ;;
            *)
                display_error "Invalid option"
                ;;
        esac
        
        prompt_continue
    done
}
