#!/usr/bin/env bash
set -euo pipefail

# Source core components
source "$CORE_DIR/imports.sh"

main() {
    log_header "NixOS System Setup"
    
    check_hardware_config
    
    # Check and migrate old system-config.nix structure (automatic)
    if [[ -f "$SYSTEM_CONFIG_FILE" ]] && command -v migrate_system_config >/dev/null 2>&1; then
        migrate_system_config || {
            log_warn "Migration failed, continuing with setup..."
        }
    fi
    
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
    
    # Check for Advanced Options first (LOAD_PROFILE: or IMPORT_CONFIG:)
    if [[ "$selected_modules_raw" =~ ^LOAD_PROFILE: ]]; then
        # Load profile from file
        local profile_path="${selected_modules_raw#LOAD_PROFILE:}"
        setup_predefined_profile "$profile_path" || exit 1
        
    elif [[ "$selected_modules_raw" =~ ^IMPORT_CONFIG: ]]; then
        # Import from existing config
        local config_path="${selected_modules_raw#IMPORT_CONFIG:}"
        log_info "Importing configuration from: $config_path"
        if [[ -f "$config_path" ]]; then
            backup_file "$SYSTEM_CONFIG_FILE" 2>/dev/null || true
            ensure_dir "$(dirname "$SYSTEM_CONFIG_FILE")"
            cp "$config_path" "$SYSTEM_CONFIG_FILE" || {
                log_error "Failed to import configuration"
                exit 1
            }
            log_success "Configuration imported successfully"
            
            # Run migration AFTER config is imported (to migrate packageModules, desktop, etc. to configs/)
            if command -v migrate_system_config >/dev/null 2>&1; then
                migrate_system_config || {
                    log_warn "Migration failed after config import, continuing anyway..."
                }
            fi
            
            # Export system type for deployment
            local system_type
            system_type=$(grep -m 1 'systemType = ' "$SYSTEM_CONFIG_FILE" | sed 's/.*systemType = "\(.*\)";.*/\1/' || echo "desktop")
            export SYSTEM_TYPE="$system_type"
            deploy_config
        else
            log_error "Configuration file not found: $config_path"
            exit 1
        fi
        
    # Check if this is a predefined profile (legacy support)
    elif profile_file=$(get_predefined_profile_file "$selected_modules_raw"); then
        # This is a predefined profile - load it directly
        setup_predefined_profile "$profile_file" || exit 1
        
    elif [[ "$selected_modules_raw" == "Desktop" ]]; then
        # Desktop preset - load desktop preset file
        local desktop_preset="$SETUP_DIR/modes/presets/desktop.nix"
        if [[ -f "$desktop_preset" ]]; then
            setup_predefined_profile "$desktop_preset" || exit 1
        else
            log_error "Desktop preset not found: $desktop_preset"
            exit 1
        fi
        
    elif [[ "$selected_modules_raw" == "Server" ]]; then
        # Server preset - load server preset file
        local server_preset="$SETUP_DIR/modes/presets/server.nix"
        if [[ -f "$server_preset" ]]; then
            setup_predefined_profile "$server_preset" || exit 1
        else
            log_error "Server preset not found: $server_preset"
            exit 1
        fi
        
    elif [[ "$selected_modules_raw" == "Homelab Server" ]]; then
        # Homelab Server uses setup_homelab
        setup_homelab "$selected_modules_raw" || exit 1
        
    elif [[ "$selected_modules_raw" == "Jetson Nano" ]]; then
        # Jetson Nano preset - load fr4iser-jetson profile
        local jetson_profile="$SETUP_DIR/modes/profiles/fr4iser-jetson"
        if [[ -f "$jetson_profile" ]]; then
            setup_predefined_profile "$jetson_profile" || exit 1
        else
            log_error "Jetson Nano profile not found: $jetson_profile"
            exit 1
        fi
        
    else
        # This is a custom setup or preset - now split into array
        IFS=' ' read -ra selected_modules <<< "$selected_modules_raw"
        local first_selection="${selected_modules[0]}"
        
        # Check if it's a system type (desktop/server) - new unified custom install
        if [[ "$first_selection" =~ ^(desktop|server)$ ]]; then
            # Unified custom install
            setup_custom "${selected_modules[@]}" || exit 1
        else
            # Legacy: Desktop/Server/Homelab (for backward compatibility)
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
    
    # Set hostname if it's null or not set
    if grep -q 'hostName = null;' "$SYSTEM_CONFIG_FILE" || ! grep -q 'hostName = ' "$SYSTEM_CONFIG_FILE"; then
        local current_hostname
        current_hostname=$(hostname)
        if [[ -n "$current_hostname" ]]; then
            if grep -q 'hostName = null;' "$SYSTEM_CONFIG_FILE"; then
                sed -i "s/hostName = null;/hostName = \"$current_hostname\";/" "$SYSTEM_CONFIG_FILE" || {
                    log_warn "Failed to update hostname"
                }
            else
                # Insert hostname after systemType
                sed -i "/systemType = /a\  hostName = \"$current_hostname\";" "$SYSTEM_CONFIG_FILE" || {
                    log_warn "Failed to add hostname"
                }
            fi
        fi
    fi
    
    log_success "Predefined profile applied successfully"
    
    # Run migration AFTER profile is loaded (to migrate packageModules, desktop, etc. to configs/)
    if command -v migrate_system_config >/dev/null 2>&1; then
        migrate_system_config || {
            log_warn "Migration failed after profile load, continuing anyway..."
        }
    fi
    
    # Export system type for deployment (read from profile)
    local system_type
    system_type=$(grep -m 1 'systemType = ' "$SYSTEM_CONFIG_FILE" | sed 's/.*systemType = "\(.*\)";.*/\1/' || echo "desktop")
    export SYSTEM_TYPE="$system_type"
    
    deploy_config
}

# Execute main function if script is run directly
check_script_execution "CORE_DIR" "main"
