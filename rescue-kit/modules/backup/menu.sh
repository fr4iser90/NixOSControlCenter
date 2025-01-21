#!/bin/bash

# Backup menu
backup_menu() {
    while true; do
        clear
        display_header "Backup Management"
        display_menu_options "Essential Backup" "Full Backup" "Verify Backup" "Back to Main Menu"
        
        backup_choice=$(prompt_menu_selection)
        
        case $backup_choice in
            1)
                if confirm_action "Are you sure you want to perform an essential backup?"; then
                    if backup_essential "$BACKUP_DIR"; then
                        display_success "Essential backup completed successfully"
                    else
                        display_error "Essential backup failed"
                    fi
                fi
                ;;
            2)
                if confirm_action "Are you sure you want to perform a full backup?"; then
                    if backup_full "$BACKUP_DIR"; then
                        display_success "Full backup completed successfully"
                    else
                        display_error "Full backup failed"
                    fi
                fi
                ;;
            3)
                if verify_backup "$BACKUP_DIR"; then
                    display_success "Backup verification successful"
                else
                    display_error "Backup verification failed"
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
