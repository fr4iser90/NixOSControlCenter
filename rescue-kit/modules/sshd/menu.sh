#!/bin/bash

# Source module scripts
source "${rescue_kit_root_dir}/modules/sshd/operations.sh"



sshd_menu() {
    display_ssh_status
    
    create_standard_menu "sshd" "SSH Management" \
        "Start SSH service" \
        "Stop SSH service" \
        "Restart SSH service" \
        "View SSH config" \
        "Back to main menu"
        
    # Register back handler
    add_menu_item "sshd" 5 "Back to main menu" "back_to_main_handler"
}
