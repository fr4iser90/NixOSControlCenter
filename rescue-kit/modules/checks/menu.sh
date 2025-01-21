#!/bin/bash

source "${rescue_kit_root_dir}/modules/checks/operations.sh"

checks_menu() {

    create_standard_menu "checks" "System Checks" \
        "Run All Checks" \
        "Detect Partitions" \
        "Verify Partitions" \
        "List USB Devices" \
        "Back to Main Menu"


    # Register back handler
    add_menu_item "checks" 6 "Back to main menu" "back_to_main_handler"
}