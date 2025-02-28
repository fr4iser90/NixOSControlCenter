#!/usr/bin/env bash
set -euo pipefail

# Source core components
source "$CORE_DIR/imports.sh"

main() {
    log_header "NixOS System Setup"
    
    # Collect system information
    collect_system_data || {
        log_error "System data collection failed"
        exit 1
    }
    
    # Get user's setup mode selection
    log_section "Setup Mode"
    
    if ! selected_modules=$(select_setup_mode); then
        log_error "Setup mode selection failed"
        exit 1
    fi
    
    # Parse selected modules into array
    IFS=' ' read -ra selected_modules <<< "$selected_modules"
    if [[ ${#selected_modules[@]} -eq 0 ]]; then
        log_error "No setup mode selected"
        exit 1
    fi
    
    log_info "Selected modules: ${selected_modules[*]}"
    
    # Execute appropriate setup based on selection
    case "${selected_modules[0]}" in
        "Desktop") 
            setup_desktop "${selected_modules[@]}" || exit 1
            ;;
        "Server")  
            setup_server "${selected_modules[@]}" || exit 1
            ;;
        "Homelab") 
            setup_homelab "${selected_modules[@]}" || exit 1
            ;;
        *)         
            log_error "Invalid setup type: ${selected_modules[0]}"
            exit 1
            ;;
    esac
    
    log_success "Setup complete! 🎉"
}

# Execute main function if script is run directly
check_script_execution "CORE_DIR" "main"