#!/bin/bash



partition_management_handler() {
    if [ -f "$rescue_kit_root_dir/modules/partition/menu.sh" ]; then
        source "$rescue_kit_root_dir/modules/partition/menu.sh"
        partition_menu
    else
        display_error "Partition Management module not found!"
        sleep 1.5
    fi
}

backup_management_handler() {
    if [ -f "$rescue_kit_root_dir/modules/backup/menu.sh" ]; then
        source "$rescue_kit_root_dir/modules/backup/menu.sh"
        backup_menu
    else
        display_error "Backup Management module not found!"
        sleep 1.5
    fi
}

system_repair_handler() {
    if [ -f "$rescue_kit_root_dir/modules/repair/menu.sh" ]; then
        source "$rescue_kit_root_dir/modules/repair/menu.sh"
        repair_menu
    else
        display_error "System Repair module not found!"
        sleep 1.5
    fi
}

rebuild_system_handler() {
    if [ -f "$rescue_kit_root_dir/modules/rebuild/menu.sh" ]; then
        source "$rescue_kit_root_dir/modules/rebuild/menu.sh"
        rebuild_menu
    else
        display_error "Rebuild System module not found!"
        sleep 1.5
    fi
}

ssh_management_handler() {
    if [ -f "$rescue_kit_root_dir/modules/sshd/menu.sh" ]; then
        source "$rescue_kit_root_dir/modules/sshd/menu.sh"
        sshd_menu
    else
        display_error "SSH Management module not found!"
        sleep 1.5
    fi
}
