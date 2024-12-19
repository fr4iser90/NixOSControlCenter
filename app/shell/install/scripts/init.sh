#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/prompts/setup-mode.sh"

main() {
    log_header "NixOS System Setup"
    
    # 1. System Checks
    source "${INSTALL_SCRIPTS_SETUP}/config/collect-system-data.sh"
    
    # 2. Installation Mode
    log_section "Setup Mode"
    
    local setup_mode
    setup_mode=$(select_setup_mode)
    
    case "$setup_mode" in
        "Custom Setup")
            source "${INSTALL_SCRIPTS_SETUP}/modes/custom-setup/custom-setup.sh"
            ;;
        *)
            # Konvertiere den Namen in einen Script-Pfad
            local script_name="${setup_mode,,}" # lowercase
            script_name="${script_name// /-}"   # spaces to dashes
            source "${INSTALL_SCRIPTS_SETUP}/modes/model-setup/${script_name}-setup.sh"
            ;;
    esac
    
    # Rest des Scripts...
    log_success "Setup complete! 🎉"
}

main "$@"