#!/usr/bin/env bash

# Always run hardware config/partition check before anything else
"$(dirname "$0")"/../../../checks/hardware/hardware-config.sh

setup_desktop() {
    log_section "Desktop Features Setup"

    # Skip the setup type ("Desktop")
    shift

    # Validate input
    if [[ $# -eq 0 ]]; then
        log_error "No features provided"
        return 1
    fi
    
    # Backup configuration
    backup_config || return 1
    
    # Update configuration
    update_desktop_system_type || return 1
    reset_feature_states || return 1
    process_desktop_features "$@" || return 1

    # Export system type for deployment
    export SYSTEM_TYPE="desktop"   
    deploy_config

    log_success "Desktop profile features updated"
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

reset_feature_states() {
    log_debug "Resetting feature states"
    
    # Setze packageModules auf leere Liste
    # Prüfe ob packageModules bereits existiert
    if grep -q "packageModules = \[" "$SYSTEM_CONFIG_FILE"; then
        # Ersetze bestehende packageModules-Liste
        sed -i '/packageModules = \[/,/\];/c\  packageModules = [];' "$SYSTEM_CONFIG_FILE" || {
            log_error "Failed to reset packageModules"
            return 1
        }
    else
        # Füge packageModules-Liste hinzu (nach systemType)
        sed -i '/systemType = "desktop";/a\  packageModules = [];' "$SYSTEM_CONFIG_FILE" || {
            log_error "Failed to add packageModules list"
            return 1
        }
    fi
    
    # Setze preset auf null falls vorhanden
    if grep -q "preset = " "$SYSTEM_CONFIG_FILE"; then
        sed -i 's/preset = .*;/preset = null;/' "$SYSTEM_CONFIG_FILE"
    fi
    
    return 0
}

process_desktop_features() {
    log_debug "Processing selected features"
    
    local feature
    for feature in "$@"; do
        enable_desktop_feature "$feature" || return 1
    done
    
    return 0
}

enable_desktop_feature() {
    local feature_input="$1"
    local feature_name
    
    # Map alte Namen zu neuen Feature-Namen (inkl. Server-Features)
    case "$feature_input" in
        "None")
            log_debug "None selected, keeping all features disabled"
            return 0
            ;;
        "Gaming-Streaming"|"streaming")
            feature_name="streaming"
            ;;
        "Gaming-Emulation"|"emulation")
            feature_name="emulation"
            ;;
        "Development-Web"|"web-dev")
            feature_name="web-dev"
            ;;
        "Development-Game"|"game-dev")
            feature_name="game-dev"
            ;;
        "python-dev")
            feature_name="python-dev"
            ;;
        "system-dev")
            feature_name="system-dev"
            ;;
        # Server-Features die auch auf Desktop verfügbar sind
        "docker")
            feature_name="docker"
            ;;
        "docker-rootless")
            feature_name="docker-rootless"
            ;;
        "database")
            feature_name="database"
            ;;
        "web-server")
            feature_name="web-server"
            ;;
        *)
            # Fallback: Verwende Input direkt als Feature-Name
            feature_name="$feature_input"
            ;;
    esac
    
    # Füge Feature zur Liste hinzu
    # Prüfe ob Feature bereits in der Liste ist
    if grep -q "\"$feature_name\"" "$SYSTEM_CONFIG_FILE"; then
        log_debug "Feature $feature_name already in list"
        return 0
    fi
    
    # Füge Feature zur Liste hinzu
    # Ersetze "packageModules = [" mit "packageModules = [ \"$feature_name\""
    # oder füge ", \"$feature_name\"" vor "];" hinzu
    if grep -q "packageModules = \[\];" "$SYSTEM_CONFIG_FILE"; then
        # Liste ist leer, ersetze
        sed -i "s/packageModules = \[\];/packageModules = [ \"$feature_name\" ];/" "$SYSTEM_CONFIG_FILE" || {
            log_error "Failed to add feature: $feature_name"
            return 1
        }
    else
        # Liste hat bereits Features, füge hinzu
        sed -i "s/];/ \"$feature_name\" ];/" "$SYSTEM_CONFIG_FILE" || {
            log_error "Failed to add feature: $feature_name"
            return 1
        }
    fi
    
    log_success "Enabled feature: $feature_name"
    return 0
}

# Export functions
export -f setup_desktop
export -f enable_desktop_feature

# Check script execution and run
check_script_execution "SYSTEM_CONFIG_FILE" "setup_desktop $*"
