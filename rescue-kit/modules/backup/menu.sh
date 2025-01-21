#!/bin/bash

source "${rescue_kit_root_dir}/modules/backup/operations.sh"

backup_menu() {
    display_backup_dir_status_handler
    
    create_standard_menu "backup" "Backup Management" \
        "Run Guided Backup" \
        "Configure Backup" \
        "Backup essential service" \
        "View Backup config" \
        "Back to main menu"
        
    # Register back handler
    add_menu_item "backup" 5 "Back to main menu" "back_to_main_handler"
}
