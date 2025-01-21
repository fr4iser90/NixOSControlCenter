#!/bin/bash


source "${rescue_kit_root_dir}/modules/rebuild/operations.sh"

mount_menu() {

    create_standard_menu "mount" "Mount Management" \
        "Validate Configuration" \
        "Rebuild System" \
        "Back to Main Menu"


    # Register back handler
    add_menu_item "checks" 3 "Back to main menu" "back_to_main_handler"
}
