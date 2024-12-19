#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/prompts/setup-mode.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/prompts/setup-rules.sh"
main() {
    log_header "NixOS System Setup"
    
    # 1. System Checks
    source "${INSTALL_SCRIPTS_SETUP}/config/collect-system-data.sh"
    
    # 2. Installation Mode
    log_section "Setup Mode"
    
    local selection
    selection=$(select_setup_mode)
    
    # Extrahiere die tatsächliche Auswahl (entferne den "Final selection" Text)
    local cleaned_selection=$(echo "$selection" | grep -v "Final selection" | tr -d '\n')
    
    # Bestimme den Basis-Typ
    local setup_type
    if [[ "$cleaned_selection" == *"Desktop"* ]]; then
        setup_type="desktop"
    elif [[ "$cleaned_selection" == *"Server"* ]]; then
        setup_type="server"
    elif [[ "$cleaned_selection" == *"Homelab"* ]]; then
        setup_type="homelab"
    else
        setup_type="custom"
    fi
    
    # Führe das entsprechende Setup-Script aus
    source "${INSTALL_SCRIPTS_SETUP}/modes/model-setup/${setup_type}-setup.sh"
    
    log_success "Setup complete! 🎉"
}

main "$@"