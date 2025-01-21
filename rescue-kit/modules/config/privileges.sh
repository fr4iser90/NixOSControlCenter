#!/bin/bash

# Verify root privileges
verify_root() {
    if [ "$EUID" -ne 0 ]; then
        handle_error "Script must be run as root"
    fi
}
