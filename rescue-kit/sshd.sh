#!/bin/bash

# Simplified SSH setup for live USB environment
# Designed for temporary remote access during system reinstallation

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Basic configuration
SSH_PORT=22
AUTHORIZED_KEYS=""

# Start SSH service
start_sshd() {
    echo -e "${YELLOW}=== Starting SSH Service ===${NC}"
    
    # Check if SSH is already running
    if pgrep sshd >/dev/null; then
        echo -e "${YELLOW}SSH is already running${NC}"
        return 0
    fi
    
    # Set root password if not set
    if ! grep -q '^root:' /etc/shadow; then
        echo -e "${YELLOW}Setting temporary root password${NC}"
        echo "root:temppass" | chpasswd
    fi
    
    # Configure authorized_keys if provided
    if [ -n "$AUTHORIZED_KEYS" ]; then
        echo -e "${YELLOW}Configuring SSH authorized_keys${NC}"
        mkdir -p /root/.ssh
        echo "$AUTHORIZED_KEYS" > /root/.ssh/authorized_keys
        chmod 700 /root/.ssh
        chmod 600 /root/.ssh/authorized_keys
    fi
    
    # Start SSH service
    echo -e "${YELLOW}Starting SSH service...${NC}"
    if /usr/sbin/sshd -p $SSH_PORT; then
        echo -e "${GREEN}SSH service started successfully on port $SSH_PORT${NC}"
        echo -e "${YELLOW}You can now connect via:${NC}"
        echo -e "  ssh root@$(hostname -I | awk '{print $1}')"
        return 0
    else
        echo -e "${RED}Failed to start SSH service${NC}"
        return 1
    fi
}

# Main function
main() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
    
    start_sshd
}

main "$@"
