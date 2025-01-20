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

# Confirm action
confirm_action() {
    local message=$1
    echo -e "${YELLOW}$message [y/N]${NC}"
    read -p "" confirm
    [[ "$confirm" =~ ^[Yy]$ ]]
}

# Mount menu
mount_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== Mount Management ===${NC}"
        echo -e "1) Mount Partitions"
        echo -e "2) Unmount Partitions"
        echo -e "3) Check Mount Status"
        echo -e "4) Back to Main Menu"
        echo -e "${BLUE}=======================${NC}"
        
        read -p "Select option: " mount_choice
        
        case $mount_choice in
            1)
                if confirm_action "Are you sure you want to mount partitions?"; then
                    mount_partitions && bind_mounts
                fi
                ;;
            2)
                if confirm_action "Are you sure you want to unmount partitions?"; then
                    unmount_partitions
                fi
                ;;
            3)
                if is_mounted; then
                    echo -e "${GREEN}Partitions are mounted${NC}"
                else
                    echo -e "${RED}Partitions are not mounted${NC}"
                fi
                ;;
            4)
                break
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        read -p "Press Enter to continue..."
    done
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
        echo -e "2) Manage Partitions"
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
                if confirm_action "Run system checks?"; then
                    run_checks
                fi
                ;;
            2)
                mount_menu
                ;;
            3)
                read -p "Enter backup directory: " backup_dir
                echo "Select backup mode:"
                echo "1) Essential data only"
                echo "2) Full system backup"
                read -p "Choice: " backup_mode
                
                case $backup_mode in
                    1) 
                        if confirm_action "Create essential backup?"; then
                            backup_menu "$backup_dir" "essential"
                        fi
                        ;;
                    2)
                        if confirm_action "Create full system backup?"; then
                            backup_menu "$backup_dir" "full"
                        fi
                        ;;
                    *) echo "Invalid choice" ;;
                esac
                ;;
            4)
                if confirm_action "Rebuild system configuration?"; then
                    if run_checks; then
                        full_rebuild
                    fi
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
                        1) 
                            if confirm_action "Start SSH daemon?"; then
                                start_sshd
                            fi
                            ;;
                        2)
                            if confirm_action "Stop SSH daemon?"; then
                                stop_sshd
                            fi
                            ;;
                        3)
                            if confirm_action "Restart SSH daemon?"; then
                                restart_sshd
                            fi
                            ;;
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
                if confirm_action "Are you sure you want to exit?"; then
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

# Start rescue system
main_menu
