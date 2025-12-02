#!/usr/bin/env bash

setup_server() {
    log_section "Server Features Setup"
    
    # Skip the setup type ("Server")
    shift
    
    # Validate remaining features
    if [[ $# -eq 0 ]]; then
        log_error "No features provided"
        return 1
    fi
    
    # Backup configuration
    backup_config || return 1
    
    # Update configuration
    update_server_system_type || return 1
    reset_feature_states || return 1
    process_server_features "$@" || return 1

    # Export system type for deployment
    export SYSTEM_TYPE="server"
    deploy_config

    log_success "Server profile features updated"
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

update_server_system_type() {
    log_debug "Setting system type to server"
    sed -i 's/systemType = ".*";/systemType = "server";/' "$SYSTEM_CONFIG_FILE" || {
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
        sed -i '/systemType = "server";/a\  packageModules = [];' "$SYSTEM_CONFIG_FILE" || {
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

process_server_features() {
    log_debug "Processing selected features"
    
    local feature
    for feature in "$@"; do
        enable_server_feature "$feature" || return 1
    done
    
    return 0
}

enable_server_feature() {
    local feature_input="$1"
    local feature_name
    
    # Map alte Namen zu neuen Feature-Namen
    case "$feature_input" in
        "None")
            log_debug "None selected, keeping all features disabled"
            return 0
            ;;
        "Docker"|"docker")
            feature_name="docker-rootless"  # Default zu rootless
            ;;
        "docker-rootless")
            feature_name="docker-rootless"
            ;;
        "Database"|"database")
            feature_name="database"
            ;;
        "web-server")
            feature_name="web-server"
            ;;
        "mail-server")
            feature_name="mail-server"
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
export -f setup_server
export -f enable_server_feature

# Check script execution
check_script_execution "SYSTEM_CONFIG_FILE" "setup_server $*"
