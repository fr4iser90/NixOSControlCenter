#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/prompts/setup-mode.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/prompts/setup-rules.sh"
source "$(dirname "${BASH_SOURCE[0]}")/deploy-build.sh"
source "$(dirname "${BASH_SOURCE[0]}")/setup/homelab/setup_users.sh"
source "$(dirname "${BASH_SOURCE[0]}")/setup/homelab/deploy-dockers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/password-check.sh"

main() {
    log_header "NixOS System Setup"
    
    # 1. Installation Mode ZUERST
    log_section "Setup Mode"
    
    # Interaktive Auswahl des Setup-Modus
    if ! selected_modules=$(select_setup_mode); then
        log_error "Setup mode selection failed"
        exit 1
    fi
    
    # Konvertiere in Array
    IFS=' ' read -ra selected_modules <<< "$selected_modules"
    
    # Debug-Ausgabe
    echo "Debug: Ausgewählte Module: ${selected_modules[@]}"
    
    # Prüfe ob überhaupt etwas ausgewählt wurde
    if [[ ${#selected_modules[@]} -eq 0 ]]; then
        log_error "No setup mode selected"
        exit 1
    fi
    
    # 2. System Checks DANACH
    source "${INSTALL_SCRIPTS_SETUP}/config/collect-system-data.sh"
    
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

    # Führe das entsprechende Setup-Script aus (VOR Deploy!)
    if ! "${INSTALL_SCRIPTS_SETUP}/modes/model-setup/${setup_type}-setup.sh" "${selected_modules[@]}"; then
        log_error "Setup script failed"
        exit 1
    fi
    
    # Spezielle Behandlung für Homelab
    if [[ "$setup_type" == "homelab" ]]; then
        # 1. User-Setup
        setup_users || {
            log_error "User setup failed"
            exit 1
        }
        
        # Bereinige mögliche %-Zeichen in der Konfigurationsdatei
        sed -i 's/%$//' "$SYSTEM_CONFIG_FILE"
        
        # 2. System-Deploy und Build
        deploy_config || {
            log_error "Config deployment failed"
            exit 1
        }
        
        # 3. Docker-Deploy vorbereiten
        deploy_docker_config || {
            log_error "Docker config preparation failed"
            exit 1
        }
        
        # Hole Script-Namen
        local hostname=$(hostname)
        local build_script="${NIXOS_CONFIG_DIR}/build-${hostname}.sh"
        local docker_script="${NIXOS_CONFIG_DIR}/deploy-docker-${hostname}.sh"
        
        log_success "Setup scripts prepared!"
        log_info "Please follow these steps:"
        echo
        echo "1. Exit this shell (Ctrl+D)"
        echo "2. Run: $build_script"
        echo "3. After reboot, run: $docker_script"
        echo
        
        read -p "Press Enter to continue..."
        exit 0
        
    else
        # Für andere Setup-Typen
        deploy_config || {
            log_error "Config deployment failed"
            exit 1
        }
        
        build_system || {
            log_error "System build failed"
            exit 1
        }
    fi
    
    log_success "Setup complete! 🎉"
}

main "$@"