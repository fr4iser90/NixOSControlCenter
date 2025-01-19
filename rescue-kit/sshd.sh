#!/bin/bash

# Configure SSH daemon
configure_sshd() {
    log "Configuring SSH daemon..."
    
    # Create backup of current config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    # Apply secure defaults
    sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    
    log "SSH configuration updated"
}

# Start SSH daemon
start_sshd() {
    log "Starting SSH daemon..."
    
    if ! systemctl start sshd; then
        log "Error: Failed to start SSH daemon"
        return 1
    fi
    
    log "SSH daemon started successfully"
    return 0
}

# Stop SSH daemon
stop_sshd() {
    log "Stopping SSH daemon..."
    
    if ! systemctl stop sshd; then
        log "Error: Failed to stop SSH daemon"
        return 1
    fi
    
    log "SSH daemon stopped successfully"
    return 0
}

# Check SSH status
check_sshd_status() {
    log "Checking SSH daemon status..."
    
    if ! systemctl status sshd; then
        log "Error: SSH daemon is not running"
        return 1
    fi
    
    log "SSH daemon is running"
    return 0
}

# Restart SSH daemon
# Completely stops and then starts the SSH service
# Use this when you need to ensure a clean state
restart_sshd() {
    log "Restarting SSH daemon..."
    
    if ! systemctl restart sshd; then
        log "Error: Failed to restart SSH daemon"
        return 1
    fi
    
    log "SSH daemon restarted successfully"
    return 0
}

# Reload SSH configuration
# Applies configuration changes without interrupting existing connections
# Use this after modifying sshd_config to apply changes
reload_sshd() {
    log "Reloading SSH configuration..."
    
    if ! systemctl reload sshd; then
        log "Error: Failed to reload SSH configuration"
        return 1
    fi
    
    log "SSH configuration reloaded successfully"
    return 0
}

# Enable SSH on boot
enable_sshd() {
    log "Enabling SSH daemon on boot..."
    
    if ! systemctl enable sshd; then
        log "Error: Failed to enable SSH daemon"
        return 1
    fi
    
    log "SSH daemon enabled on boot"
    return 0
}

# Main SSH management function
manage_sshd() {
    local action=$1
    
    case $action in
        start)
            start_sshd
            ;;
        stop)
            stop_sshd
            ;;
        restart)
            restart_sshd
            ;;
        status)
            check_sshd_status
            ;;
        reload)
            reload_sshd
            ;;
        enable)
            enable_sshd
            ;;
        configure)
            configure_sshd
            ;;
        *)
            log "Invalid SSH action: $action"
            return 1
            ;;
    esac
}
