#!/bin/bash

# Check if partitions are mounted
is_mounted() {
    # Ensure MOUNT_DIR is available
    if [[ -z "$MOUNT_DIR" ]]; then
        echo "Error: MOUNT_DIR is not set"
        return 1
    fi
    
    if mount | grep -q "$MOUNT_DIR"; then
        return 0
    else
        return 1
    fi
}


# Show system status overview
show_status() {
    display_header "Current Status"
    
    key_value "Mounted Partitions" "$(if is_mounted; then echo -e "${UI_COLOR_SUCCESS}Yes${UI_COLOR_FG}"; else echo -e "${UI_COLOR_ERROR}No${UI_COLOR_FG}"; fi)"
    key_value "SSH Daemon" "$(if check_sshd_status &>/dev/null; then echo -e "${UI_COLOR_SUCCESS}Running${UI_COLOR_FG}"; else echo -e "${UI_COLOR_ERROR}Stopped${UI_COLOR_FG}"; fi)"
    key_value "Last Backup" "$(if [ -f "$BACKUP_DIR/last_backup" ]; then cat "$BACKUP_DIR/last_backup"; else echo -e "${UI_COLOR_ERROR}Never${UI_COLOR_FG}"; fi)"
    key_value "Last Rebuild" "$(if [ -f "$REBUILD_LOG" ]; then tail -1 "$REBUILD_LOG"; else echo -e "${UI_COLOR_ERROR}Never${UI_COLOR_FG}"; fi)"
    
    echo ""
}
