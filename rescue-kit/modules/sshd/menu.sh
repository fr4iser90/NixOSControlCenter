#!/bin/bash

sshd_menu() {
    display_header "SSH Management"
    
    # Check SSH service status
    if systemctl is-active --quiet sshd; then
        echo -e "SSH Service Status: \e[32mRunning\e[0m"
        echo -e "Listening Port: $(ss -tlnp | grep sshd | awk '{print $4}' | cut -d':' -f2)"
        echo -e "Active Connections: $(ss -tn src :22 | grep -v LISTEN | wc -l)"
    else
        echo -e "SSH Service Status: \e[31mStopped\e[0m"
    fi
    
    echo -e "\nOptions:"
    echo "1. Start SSH service"
    echo "2. Stop SSH service"
    echo "3. Restart SSH service"
    echo "4. View SSH config"
    echo "5. Back to main menu"
    
    ssh_choice=$(prompt_menu_selection)
    
    case $ssh_choice in
        1)
            if systemctl start sshd; then
                display_success "SSH service started successfully"
            else
                display_error "Failed to start SSH service"
            fi
            ;;
        2)
            if systemctl stop sshd; then
                display_success "SSH service stopped successfully"
            else
                display_error "Failed to stop SSH service"
            fi
            ;;
        3)
            if systemctl restart sshd; then
                display_success "SSH service restarted successfully"
            else
                display_error "Failed to restart SSH service"
            fi
            ;;
        4)
            less /etc/ssh/sshd_config
            ;;
        5)
            return
            ;;
        *)
            display_error "Invalid option"
            ;;
    esac
    
    prompt_continue
}
