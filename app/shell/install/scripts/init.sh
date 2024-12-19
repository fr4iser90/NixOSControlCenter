#!/usr/bin/env bash
set -euo pipefail

# Lade Umgebung
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

main() {
    log_header "NixOS System Setup"
    
    # Hardware Checks
    for check in cpu gpu memory storage; do
        source "${CHECKS_DIR}/hardware/${check}.sh"
    done
    
    # System Checks
    for check in locale network bootloader; do
        source "${CHECKS_DIR}/system/${check}.sh"
    done
    
    # Setup
    if ask_user "Use predefined setup?"; then
        source "${SETUP_DIR}/modes/predefined.sh"
    else
        source "${SETUP_DIR}/modes/personalized.sh"
    fi
    
    log_success "Setup complete! 🎉"
}

main "$@"