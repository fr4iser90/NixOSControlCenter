#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

main() {
    log_header "NixOS System Setup"
    
    # 1. System Checks
    log_section "System Detection"
    source "${SETUP_DIR}/config/collect-system-data.sh"
    
    # 2. Installation Mode
    log_section "Setup Mode"
    if ask_user "Use predefined setup?"; then
        # Model Setup
        source "${SETUP_DIR}/modes/model-setup/$(select_model)-setup.sh"
    else
        # Custom Setup
        source "${SETUP_DIR}/modes/custom-setup/custom-setup.sh"
    fi
    
    # 3. Generate Config
    log_section "Configuration"
    source "${SETUP_DIR}/config/generate-config.sh"
    
    # 4. Validate
    source "${SETUP_DIR}/config/validate-config.sh"
    
    # 5. Install
    log_section "Installation"
    if confirm_installation; then
        source "${SETUP_DIR}/install/prepare-system.sh"
        source "${SETUP_DIR}/install/copy-config.sh"
        source "${SETUP_DIR}/install/build-system.sh"
    fi
    
    log_success "Setup complete! 🎉"
}

main "$@"