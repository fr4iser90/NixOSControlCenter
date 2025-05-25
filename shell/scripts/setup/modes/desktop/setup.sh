#!/usr/bin/env bash

# Always run hardware config/partition check before anything else
"$(dirname "$0")"/../../../checks/hardware/hardware-config.sh

setup_desktop() {
    log_section "Desktop Modules Setup"

    # Skip the setup type ("Desktop")
    shift

    # Validate input
    if [[ $# -eq 0 ]]; then
        log_error "No modules provided"
        return 1
    fi
    
    # Backup configuration
    backup_config || return 1
    
    # Update configuration
    update_desktop_system_type || return 1
    reset_module_states || return 1
    process_desktop_modules "$@" || return 1

    # Export system type for deployment
    export SYSTEM_TYPE="desktop"   
    deploy_config

    log_success "Desktop profile modules updated"
}

backup_config() {
    if [[ -f "$SYSTEM_CONFIG_FILE" ]]; then
        backup_file "$SYSTEM_CONFIG_FILE" || {
            log_error "Failed to create backup"
            return 1
        }
    fi
    return 0
}

update_desktop_system_type() {
    log_debug "Setting system type to desktop"
    sed -i 's/systemType = ".*";/systemType = "desktop";/' "$SYSTEM_CONFIG_FILE" || {
        log_error "Failed to update system type"
        return 1
    }
    return 0
}

reset_module_states() {
    log_debug "Resetting module states"
    
    local module_updates=(
        '/gaming = {/,/};/s/streaming = .*;/streaming = false;/'
        '/gaming = {/,/};/s/emulation = .*;/emulation = false;/'
        '/development = {/,/};/s/game = .*;/game = false;/'
        '/development = {/,/};/s/web = .*;/web = false;/'
    )
    
    for update in "${module_updates[@]}"; do
        sed -i "$update" "$SYSTEM_CONFIG_FILE" || {
            log_error "Failed to reset module states"
            return 1
        }
    done
    
    return 0
}

process_desktop_modules() {
    log_debug "Processing selected modules"
    
    local module
    for module in "$@"; do
        enable_desktop_module "$module" || return 1
    done
    
    return 0
}

enable_desktop_module() {
    local module="$1"
    local update_command
    
    case "$module" in
        "None")
            # Für "None" machen wir nichts, da reset_module_states bereits alles auf false gesetzt hat
            log_debug "None selected, keeping all modules disabled"
            return 0
            ;;
#        "Gaming")
#            # Aktiviere alle Gaming-Features
#            update_command='/gaming = {/,/};/s/streaming = .*;/streaming = true;/; /gaming = {/,/};/s/emulation = .*;/emulation = true;/'
#            ;;
        "Gaming-Streaming")
            update_command='/gaming = {/,/};/s/streaming = .*;/streaming = true;/'
            ;;
        "Gaming-Emulation")
            update_command='/gaming = {/,/};/s/emulation = .*;/emulation = true;/'
            ;;
#        "Development")
#            # Aktiviere alle Development-Features
#            update_command='/development = {/,/};/s/game = .*;/game = true;/; /development = {/,/};/s/web = .*;/web = true;/'
#            ;;
        "Development-Web")
            update_command='/development = {/,/};/s/web = .*;/web = true;/'
            ;;
        "Development-Game")
            update_command='/development = {/,/};/s/game = .*;/game = true;/'
            ;;
        *)
            log_error "Unknown module: $module"
            return 1
            ;;
    esac
    
    sed -i "$update_command" "$SYSTEM_CONFIG_FILE" || {
        log_error "Failed to enable module: $module"
        return 1
    }
    
    log_success "Enabled module: $module"
    return 0
}

# Export functions
export -f setup_desktop
export -f enable_desktop_module

# Check script execution and run
check_script_execution "SYSTEM_CONFIG_FILE" "setup_desktop $*"
