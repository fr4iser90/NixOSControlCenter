#!/bin/bash

view_ssh_config_handler() {
    less /etc/ssh/sshd_config
    prompt_continue
}

start_ssh_service_handler() {
    if systemctl start sshd; then
        display_success "SSH service started successfully"
    else
        display_error "Failed to start SSH service"
    fi
    prompt_continue
}

stop_ssh_service_handler() {
    if systemctl stop sshd; then
        display_success "SSH service stopped successfully"
    else
        display_error "Failed to stop SSH service"
    fi
    prompt_continue
}

restart_ssh_service_handler() {
    if systemctl restart sshd; then
        display_success "SSH service restarted successfully"
    else
        display_error "Failed to restart SSH service"
    fi
    prompt_continue
}

display_ssh_status() {
    display_header "SSH Management"
    
    if systemctl is-active --quiet sshd; then
        echo -e "SSH Service Status: \e[32mRunning\e[0m"
        echo -e "Listening Port: $(ss -tlnp | grep sshd | awk '{print $4}' | cut -d':' -f2)"
        echo -e "Active Connections: $(ss -tn src :22 | grep -v LISTEN | wc -l)"
    else
        echo -e "SSH Service Status: \e[31mStopped\e[0m"
    fi
}
