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
    
    # Hole die Auswahl und konvertiere sie in ein Array
    IFS=' ' read -ra selected_modules <<< "$(select_setup_mode)"
    
    # Debug-Ausgabe
    echo "Debug: Ausgewählte Module: ${selected_modules[@]}"
    
    # Bestimme den Basis-Typ
    local setup_type
    if [[ "${selected_modules[0]}" == "Desktop" ]]; then
        setup_type="desktop"
    elif [[ "${selected_modules[0]}" == "Server" ]]; then
        setup_type="server"
    elif [[ "${selected_modules[0]}" == "Homelab" ]]; then
        setup_type="homelab"
    else
        setup_type="custom"
    fi
    
    # Führe das entsprechende Setup-Script aus
    "${INSTALL_SCRIPTS_SETUP}/modes/model-setup/${setup_type}-setup.sh" "${selected_modules[@]}"
    
    log_success "Setup complete! 🎉"
}

main "$@"