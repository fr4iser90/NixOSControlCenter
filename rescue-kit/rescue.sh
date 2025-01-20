#!/bin/bash

# Source configuration
source ./config.sh

# Source all modules
source ./mount.sh
source ./checks.sh
source ./rebuild.sh
source ./backup.sh
source ./sshd.sh

# Colors for UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Show status indicators
show_status() {
    echo -e "\n${BLUE}=== Current Status ===${NC}"
    echo -e "Mounted Partitions: $(if is_mounted; then echo -e "${GREEN}Yes${NC}"; else echo -e "${RED}No${NC}"; fi)"
    echo -e "SSH Daemon: $(if check_sshd_status &>/dev/null; then echo -e "${GREEN}Running${NC}"; else echo -e "${RED}Stopped${NC}"; fi)"
    echo -e "Last Backup: $(if [ -f "$BACKUP_DIR/last_backup" ]; then cat "$BACKUP_DIR/last_backup"; else echo -e "${RED}Never${NC}"; fi)"
    echo -e "Last Rebuild: $(if [ -f "$REBUILD_LOG" ]; then tail -1 "$REBUILD_LOG"; else echo -e "${RED}Never${NC}"; fi)"
    echo -e "${BLUE}=====================${NC}\n"
}

# Main menu
main_menu() {
    while true; do
        clear
        echo -e "${BLUE}========================================${NC}"
        echo -e " ${GREEN}NixOS Rescue Kit - Main Menu${NC}"
        echo -e "${BLUE}========================================${NC}"
        show_status
        echo -e "1) Run System Checks"
        echo -e "2) Mount/Unmount Partitions"
        echo -e "3) Backup System"
        echo -e "4) Rebuild System"
        echo -e "5) Manage SSH Daemon"
        echo -e "6) View Logs"
        echo -e "7) Help"
        echo -e "8) Exit"
        echo -e "${BLUE}========================================${NC}"
        
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
                while true; do
                    clear
                    echo -e "${BLUE}=== SSH Management ===${NC}"
                    echo -e "1) Start SSH Daemon"
                    echo -e "2) Stop SSH Daemon"
                    echo -e "3) Restart SSH Daemon"
                    echo -e "4) Check SSH Status"
                    echo -e "5) Configure SSH"
                    echo -e "6) Enable SSH on Boot"
                    echo -e "7) Back to Main Menu"
                    echo -e "${BLUE}======================${NC}"
                    
                    read -p "Select option: " ssh_choice
                    
                    case $ssh_choice in
                        1) start_sshd ;;
                        2) stop_sshd ;;
                        3) restart_sshd ;;
                        4) check_sshd_status ;;
                        5) configure_sshd ;;
                        6) enable_sshd ;;
                        7) break ;;
                        *) echo -e "${RED}Invalid option${NC}" ;;
                    esac
                    
                    read -p "Press Enter to continue..."
                done
                ;;
            6)
                echo -e "${BLUE}=== Log Viewer ===${NC}"
                echo -e "1) System Checks Log"
                echo -e "2) Backup Log"
                echo -e "3) Rebuild Log"
                echo -e "4) SSH Log"
                echo -e "5) Main Log"
                echo -e "6) Back to Main Menu"
                echo -e "${BLUE}=================${NC}"
                
                read -p "Select log to view: " log_choice
                
                case $log_choice in
                    1) less "$CHECK_LOG" ;;
                    2) less "$BACKUP_LOG" ;;
                    3) less "$REBUILD_LOG" ;;
                    4) less "$SSHD_LOG" ;;
                    5) less "$LOG_FILE" ;;
                    6) continue ;;
                    *) echo -e "${RED}Invalid choice${NC}" ;;
                esac
                ;;
            7)
                clear
                echo -e "${GREEN}=== NixOS Rescue Kit Help ===${NC}"
                echo -e "This tool provides essential recovery and maintenance"
                echo -e "functions for NixOS systems. Use the menu options to:"
                echo -e ""
                echo -e "${BLUE}System Checks${NC} - Verify system health and configuration"
                echo -e "${BLUE}Mount Partitions${NC} - Prepare system for recovery"
                echo -e "${BLUE}Backup System${NC} - Create essential or full backups"
                echo -e "${BLUE}Rebuild System${NC} - Rebuild NixOS configuration"
                echo -e "${BLUE}SSH Management${NC} - Control remote access"
                echo -e ""
                echo -e "Press q to return to main menu"
                read -p ""
                ;;
            8)
                echo -e "${YELLOW}Are you sure you want to exit? [y/N]${NC}"
                read -p "" confirm_exit
                if [[ "$confirm_exit" =~ ^[Yy]$ ]]; then
                    echo -e "${GREEN}Exiting...${NC}"
                    exit 0
                fi
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
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
