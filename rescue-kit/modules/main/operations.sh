#!/bin/bash

# Guided walkthrough: Automates the rescue process
run_rescue_handler() {
    echo "Starting guided walkthrough..."

    # Step 1: Detect and select partitions
    if ! detect_and_select_partitions; then
        display_error "Partition detection failed!"
        return 1
    fi

    # Step 3: Mount partitions for recovery
    if ! mount_partitions; then
        display_error "Failed to mount partitions!"
        return 1
    fi

    # Step 4: Validate backup size and copy files
    if ! validate_and_copy_backups; then
        display_error "Backup validation or file copying failed!"
        return 1
    fi

    # Step 5: Prepare system for chroot
    if ! prepare_system_chroot; then
        display_error "System preparation failed!"
        return 1
    fi

    # Step 6: Rebuild the system
    if ! rebuild_system; then
        display_error "System rebuild failed!"
        return 1
    fi

    display_success "Guided walkthrough completed successfully!"
    return 0
}

# Step 1: Detect and select partitions
detect_and_select_partitions() {
    echo "Step 1: Detect and select partitions..."
    suggest_and_select_partitions
    sleep 1.0
    return 0
}

# Step 2: Mount partitions
mount_partitions() {
    echo "Step 2: Mount partitions..."
    sleep 1.0
    mount_partitions_handler
    sleep 1.0
    return 0
}

# Step 4: Validate and copy backups
validate_and_copy_backups() {
    echo "Validating and copying backups..."
    sleep 1.0
    backup_essential_handler
    sleep 1.0
    return 0
}

# Step 5: Prepare system for chroot
prepare_system_chroot() {
    echo "Preparing system for chroot..."
    # Mount-Bindings (proc, sys, etc.) vorbereiten
    return 0
}

# Step 6: Rebuild system
rebuild_system() {
    echo "Rebuilding the system..."
    # System-Rebuild-Logik hier
    return 0
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


# Show system status overview
show_status_handler() {
    display_header "Current Status"
    
    key_value "Mounted Partitions" "$(if is_mounted; then echo -e "${UI_COLOR_SUCCESS}Yes${UI_COLOR_FG}"; else echo -e "${UI_COLOR_ERROR}No${UI_COLOR_FG}"; fi)"
    key_value "SSH Daemon" "$(if check_sshd_status &>/dev/null; then echo -e "${UI_COLOR_SUCCESS}Running${UI_COLOR_FG}"; else echo -e "${UI_COLOR_ERROR}Stopped${UI_COLOR_FG}"; fi)"
    key_value "Last Backup" "$(if [ -f "$BACKUP_DIR/last_backup" ]; then cat "$BACKUP_DIR/last_backup"; else echo -e "${UI_COLOR_ERROR}Never${UI_COLOR_FG}"; fi)"
    key_value "Last Rebuild" "$(if [ -f "$REBUILD_LOG" ]; then tail -1 "$REBUILD_LOG"; else echo -e "${UI_COLOR_ERROR}Never${UI_COLOR_FG}"; fi)"
    
    echo ""
}