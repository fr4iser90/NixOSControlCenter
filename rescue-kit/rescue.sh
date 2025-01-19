#!/bin/bash

# Source configuration
source ./config.sh

# Source all modules
source ./mount.sh
source ./checks.sh
source ./rebuild.sh
source ./backup.sh
source ./sshd.sh

# Main menu
main_menu() {
    while true; do
        echo "========================================"
        echo " NixOS Rescue Kit - Main Menu"
        echo "========================================"
        echo "1) Run System Checks"
        echo "2) Mount Partitions"
        echo "3) Backup System"
        echo "4) Rebuild System"
        echo "5) Start SSH Daemon"
        echo "6) Exit"
        echo "========================================"
        
        read -p "Select option: " choice
        
        case $choice in
            1)
                run_checks
                ;;
            2)
                mount_partitions
                bind_mounts
                ;;
            3)
                read -p "Enter backup directory: " backup_dir
                echo "Select backup mode:"
                echo "1) Essential data only"
                echo "2) Full system backup"
                read -p "Choice: " backup_mode
                
                case $backup_mode in
                    1) backup_menu "$backup_dir" "essential" ;;
                    2) backup_menu "$backup_dir" "full" ;;
                    *) echo "Invalid choice" ;;
                esac
                ;;
            4)
                if run_checks && mount_partitions && bind_mounts; then
                    full_rebuild
                fi
                ;;
            5)
                start_sshd
                ;;
            6)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
        
        read -p "Press Enter to continue..."
    done
}

# Initialize rescue system
initialize_rescue() {
    # Check if running in chroot
    if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
        echo "Running in chroot environment"
        return 0
    fi
    
    # Run initial checks
    if ! run_checks; then
        echo "System checks failed"
        return 1
    fi
    
    # Mount partitions
    if ! mount_partitions; then
        echo "Failed to mount partitions"
        return 1
    fi
    
    # Set bind mounts
    if ! bind_mounts; then
        echo "Failed to set bind mounts"
        return 1
    fi
    
    return 0
}

# Start rescue system
if initialize_rescue; then
    main_menu
else
    echo "Rescue system initialization failed"
    exit 1
fi
