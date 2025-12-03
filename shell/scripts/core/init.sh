#!/usr/bin/env bash
set -euo pipefail

# Source core components
source "$CORE_DIR/imports.sh"

main() {
    log_header "NixOS System Setup"
    
    check_hardware_config
    # Collect system information
    collect_system_data || {
        log_error "System data collection failed"
        exit 1
    }
    
    # Get user's setup mode selection
    log_section "Setup Mode"
    
    if ! selected_modules_raw=$(select_setup_mode); then
        log_error "Setup mode selection failed"
        exit 1
    fi
    
    if [[ -z "$selected_modules_raw" ]]; then
        log_error "No setup mode selected"
        exit 1
    fi
    
    log_info "Selected modules: $selected_modules_raw"
    
    # Check if this is a predefined profile FIRST (before splitting)
    local profile_file
    
    if profile_file=$(get_predefined_profile_file "$selected_modules_raw"); then
        # This is a predefined profile - load it directly
        setup_predefined_profile "$profile_file" || exit 1
    elif [[ "$selected_modules_raw" == "Homelab Server" ]]; then
        # Homelab Server uses setup_homelab
        setup_homelab "$selected_modules_raw" || exit 1
    else
        # This is a custom setup - now split into array
        IFS=' ' read -ra selected_modules <<< "$selected_modules_raw"
        local first_selection="${selected_modules[0]}"
        
        case "$first_selection" in
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
                log_error "Invalid setup type: $first_selection"
                exit 1
                ;;
        esac
    fi
    
    log_success "Setup complete! 🎉"
}

# Map predefined profile names to file names
get_predefined_profile_file() {
    local profile_name="$1"
    local profile_file=""
    
    case "$profile_name" in
        "Fr4iser Personal Desktop")
            profile_file="fr4iser-home"
            ;;
        "Gira Personal Desktop")
            profile_file="gira-home"
            ;;
        "Fr4iser Jetson Nano")
            profile_file="fr4iser-jetson"
            ;;
        "Homelab Server")
            # Homelab uses the setup_homelab function, not a profile file
            return 1
            ;;
        *)
            return 1
            ;;
    esac
    
    local profile_path="$SETUP_DIR/modes/profiles/$profile_file"
    if [[ -f "$profile_path" ]]; then
        echo "$profile_path"
        return 0
    else
        log_error "Profile file not found: $profile_path"
        return 1
    fi
}

# Setup predefined profile by copying the profile file
setup_predefined_profile() {
    local profile_file="$1"
    
    log_section "Setting up Predefined Profile"
    log_info "Loading profile from: $profile_file"
    
    # Backup existing config
    if [[ -f "$SYSTEM_CONFIG_FILE" ]]; then
        backup_file "$SYSTEM_CONFIG_FILE" || {
            log_error "Failed to create backup"
            return 1
        }
    fi
    
    # Copy profile file to system config
    ensure_dir "$(dirname "$SYSTEM_CONFIG_FILE")"
    cp "$profile_file" "$SYSTEM_CONFIG_FILE" || {
        log_error "Failed to copy profile file"
        return 1
    }
    
    log_success "Predefined profile applied successfully"
    
    # Export system type for deployment (read from profile)
    local system_type
    system_type=$(grep -m 1 'systemType = ' "$SYSTEM_CONFIG_FILE" | sed 's/.*systemType = "\(.*\)";.*/\1/' || echo "desktop")
    export SYSTEM_TYPE="$system_type"
    
    deploy_config
}

# Execute main function if script is run directly
check_script_execution "CORE_DIR" "main"
