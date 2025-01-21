#!/bin/bash

# Main menu handlers
system_checks_handler() {
    if [ -f "$rescue_kit_root_dir/modules/checks/menu.sh" ]; then
        source "$rescue_kit_root_dir/modules/checks/menu.sh"
        checks_menu
    else
        display_error "System Checks module not found!"
        sleep 1.5
    fi
}

partition_management_handler() {
    if [ -f "$rescue_kit_root_dir/modules/mount/menu.sh" ]; then
        source "$rescue_kit_root_dir/modules/mount/menu.sh"
        mount_menu
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

help_handler() {
    display_help
    prompt_continue
}

exit_handler() {
    if confirm_action "Are you sure you want to exit?"; then
        display_success "Exiting..."
        exit 0
    fi
}
