#!/bin/bash


source "${rescue_kit_root_dir}/modules/mount/operations.sh"

mount_menu() {

    create_standard_menu "mount" "Mount Management" \
        "Detect Partitions" \
        "Mount Partitions" \
        "Unmount Partitions" \
        "Check Partitions Status" \
        "List USB Devices" \
        "Back to Main Menu"


    # Register back handler
    add_menu_item "checks" 6 "Back to main menu" "back_to_main_handler"
}
