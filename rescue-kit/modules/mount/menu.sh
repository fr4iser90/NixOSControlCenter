#!/bin/bash

# Mount menu
mount_menu() {
    while true; do
        clear
        display_header "Mount Management"
        display_menu_options "Mount Partitions" "Unmount Partitions" "Check Mount Status" "Back to Main Menu"
        
        mount_choice=$(prompt_menu_selection)
        
        case $mount_choice in
            1)
                if confirm_action "Are you sure you want to mount partitions?"; then
                    mount_partitions && bind_mounts
                fi
                ;;
            2)
                if confirm_action "Are you sure you want to unmount partitions?"; then
                    unmount_partitions
                fi
                ;;
            3)
                if is_mounted; then
                    display_success "Partitions are mounted"
                else
                    display_error "Partitions are not mounted"
                fi
                ;;
            4)
                break
                ;;
            *)
                display_error "Invalid option"
                ;;
        esac
        
        prompt_continue
    done
}