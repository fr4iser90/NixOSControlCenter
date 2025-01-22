#!/bin/bash

source "${rescue_kit_root_dir}/modules/partition/operations.sh"

partition_menu() {

    create_standard_menu "partition" "Partition Management" \
        "Detect Partitions" \
        "Suggest Partitions" \
        "Select Partitions" \
        "Mount Partitions" \
        "Unmount Partitions" \
        "Check Partitions Status" \
        "List USB Devices" \
        "Back to Main Menu"


    # Register back handler
    add_menu_item "checks" 9 "Back to main menu" "back_to_main_handler"
}