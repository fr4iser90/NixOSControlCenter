#!/bin/bash

# Configuration menu
config_menu() {
    while true; do
        clear
        display_header "Configuration Management"
        display_menu_options "Set Root Partition" "Set Boot Partition" "Set Mount Directory" "Set Backup Directory" "Set Log File" "View Current Configuration" "Back to Main Menu"
        show_config_paths
        config_choice=$(prompt_menu_selection)
        
        case $config_choice in
            1)
                if set_root_part; then
                    display_success "Root partition configured successfully"
                else
                    display_error "Failed to configure root partition"
                fi
                ;;
            2)
                if set_boot_part; then
                    display_success "Boot partition configured successfully"
                else
                    display_error "Failed to configure boot partition"
                fi
                ;;
            3)
                if set_mount_dir; then
                    display_success "Mount directory configured successfully"
                else
                    display_error "Failed to configure mount directory"
                fi
                ;;
            4)
                if set_backup_dir; then
                    display_success "Backup directory configured successfully"
                else
                    display_error "Failed to configure backup directory"
                fi
                ;;
            5)
                if set_log_file; then
                    display_success "Log file configured successfully"
                else
                    display_error "Failed to configure log file"
                fi
                ;;
            6)
                show_config_paths
                ;;
            7)
                break
                ;;
            *)
                display_error "Invalid option"
                ;;
        esac
        
        prompt_continue
    done
}
