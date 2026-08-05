#!/usr/bin/env bash

# Always run hardware config/partition check before anything else
if [[ -n "${CHECKS_DIR:-}" ]]; then
    source "$CHECKS_DIR/hardware/hardware-config.sh"
else
    "$(dirname "$0")"/../../checks/hardware/hardware-config.sh
fi

# Helper function to update packages-config.nix
# Uses config-writer: write_packages_config()
update_packages_config() {
    local package_modules="$1"
    local browsers=""
    if declare -F ncc_gui_answer >/dev/null 2>&1; then
        browsers=$(ncc_gui_answer BROWSERS 2>/dev/null || true)
    fi
    [[ -z "$browsers" ]] && browsers="firefox"
    export PACKAGE_SYSTEM_PACKAGES="$browsers"

    if [[ -n "$package_modules" ]]; then
        read -ra mod_array <<< "$package_modules"
        write_packages_config "${mod_array[@]}" || return 1
    else
        write_packages_config || return 1
    fi
    unset PACKAGE_SYSTEM_PACKAGES
}

# Backup configuration including systemConfig directory
backup_config() {
    if [[ -f "$SYSTEM_CONFIG_FILE" ]]; then
        backup_file "$SYSTEM_CONFIG_FILE" || {
            log_error "Failed to create backup"
            return 1
        }
    fi
    if [[ -d "$(dirname "$SYSTEM_CONFIG_FILE")/systemConfig" ]]; then
        local backup_root="/var/backup/nixos/directories"
        local backup_dir="$backup_root/systemConfig.$(date +%Y%m%d_%H%M%S)"
        if [[ ! -d "$backup_root" ]]; then
            mkdir -p "$backup_root"
            chmod 700 "$backup_root" 2>/dev/null || sudo chmod 700 "$backup_root" 2>/dev/null || true
            chown root:root "$backup_root" 2>/dev/null || sudo chown root:root "$BACKUP_ROOT" 2>/dev/null || true
        else
            mkdir -p "$backup_root"
        fi
        if cp -r "$(dirname "$SYSTEM_CONFIG_FILE")/systemConfig" "$backup_dir" 2>/dev/null || sudo cp -r "$(dirname "$SYSTEM_CONFIG_FILE")/systemConfig" "$backup_dir" 2>/dev/null; then
            chmod -R 700 "$backup_dir" 2>/dev/null || sudo chmod -R 700 "$backup_dir" 2>/dev/null || true
            find "$backup_dir" -type f -exec chmod 600 {} \; 2>/dev/null || sudo find "$backup_dir" -type f -exec chmod 600 {} \; 2>/dev/null || true
            chown -R root:root "$backup_dir" 2>/dev/null || sudo chown -R root:root "$backup_dir" 2>/dev/null || true
            ls -dt "$backup_root"/systemConfig.* 2>/dev/null | tail -n +6 | xargs -r rm -rf 2>/dev/null || sudo xargs -r rm -rf 2>/dev/null || true
            log_info "Backup created: $backup_dir"
        fi
    fi
    return 0
}

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
    
    # Update packages based on selected features
    local package_modules=""
    for feature in "$@"; do
        if [[ "$feature" == "None" ]]; then
            continue
        fi
        
        # Map feature names
        case "$feature" in
            "Gaming-Streaming"|"streaming") feature_name="streaming" ;;
            "Gaming-Emulation"|"emulation") feature_name="emulation" ;;
            "Development-Web"|"web-dev") feature_name="web-dev" ;;
            "Development-Game"|"game-dev") feature_name="game-dev" ;;
            "python-dev") feature_name="python-dev" ;;
            "system-dev") feature_name="system-dev" ;;
            "docker") feature_name="docker" ;;
            "database") feature_name="database" ;;
            "web-server") feature_name="web-server" ;;
            *) feature_name="$feature" ;;
        esac
        
        if [[ -n "$package_modules" ]]; then
            package_modules="$package_modules $feature_name"
        else
            package_modules="$feature_name"
        fi
    done
    
    # Write packages config (v1)
    if [[ -n "$package_modules" ]]; then
        update_packages_config "$package_modules" || return 1
    else
        update_packages_config "" || return 1
    fi

    # Export system type for deployment
    export SYSTEM_TYPE="desktop"   
    deploy_config

    log_success "Desktop profile features updated (v1 modular)"
}

# Export functions
export -f setup_desktop
export -f update_packages_config
export -f backup_config

# Check script execution and run
check_script_execution "SYSTEM_CONFIG_FILE" "setup_desktop $*"
