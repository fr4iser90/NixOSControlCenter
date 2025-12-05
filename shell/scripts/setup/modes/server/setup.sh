#!/usr/bin/env bash

# Helper function to update packages-config.nix
update_packages_config() {
    local config_file="$(dirname "$SYSTEM_CONFIG_FILE")/configs/packages-config.nix"
    local package_modules="$1"
    
    # Create configs directory if it doesn't exist
    mkdir -p "$(dirname "$config_file")"
    
    # Read existing preset if it exists
    local existing_preset="null"
    local existing_additional=""
    
    if [ -f "$config_file" ]; then
        existing_preset=$(grep -o 'preset = [^;]*' "$config_file" 2>/dev/null | grep -o '[^=]*$' | tr -d ' ' || echo "null")
        existing_additional=$(grep -A1 'additionalPackageModules' "$config_file" 2>/dev/null || echo "")
    fi
    
    # Build package modules list
    local modules_list=""
    if [[ -n "$package_modules" ]]; then
        modules_list=$(echo "$package_modules" | sed 's/^/    "/;s/$/"/' | sed 's/ /"\n    "/g')
    fi
    
    # Write complete packages-config.nix
    cat > "$config_file" <<EOF
{
  # Package-Modules
  packageModules = [
$modules_list
  ];
}
EOF
}

# Helper function to update system-config.nix (only systemType)
update_system_type() {
    local system_type="$1"
    local temp_file=$(mktemp)
    
    # Read existing system-config.nix
    if [ -f "$SYSTEM_CONFIG_FILE" ]; then
        cp "$SYSTEM_CONFIG_FILE" "$temp_file"
    else
        # Create minimal system-config.nix if it doesn't exist
        cat > "$temp_file" <<EOF
{
  systemType = "$system_type";
  hostName = "$(hostname)";
  system = {
    channel = "stable";
    bootloader = "systemd-boot";
  };
  allowUnfree = true;
  users = {};
  timeZone = "Europe/Berlin";
}
EOF
    fi
    
    # Update systemType
    sed -i "s/systemType = \".*\";/systemType = \"$system_type\";/" "$temp_file"
    
    # Apply changes
    if [[ -w "$SYSTEM_CONFIG_FILE" ]]; then
        mv "$temp_file" "$SYSTEM_CONFIG_FILE"
    else
        sudo mv "$temp_file" "$SYSTEM_CONFIG_FILE" || {
            log_error "Failed to update system-config.nix"
            rm "$temp_file"
            return 1
        }
    fi
}

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
    update_system_type "server" || return 1
    
    # Build package modules list
    local package_modules=""
    for feature in "$@"; do
        if [[ "$feature" == "None" ]]; then
            continue
        fi
        
        # Map feature names
        case "$feature" in
            "Docker"|"docker") feature_name="docker" ;;
            "Database"|"database") feature_name="database" ;;
            "web-server") feature_name="web-server" ;;
            "mail-server") feature_name="mail-server" ;;
            *) feature_name="$feature" ;;
        esac
        
        if [[ -n "$package_modules" ]]; then
            package_modules="$package_modules $feature_name"
        else
            package_modules="$feature_name"
        fi
    done
    
    # Update packages-config.nix
    if [[ -n "$package_modules" ]]; then
        update_packages_config "$package_modules" || return 1
    else
        update_packages_config "" || return 1
    fi

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
    # Also backup configs directory if it exists
    if [[ -d "$(dirname "$SYSTEM_CONFIG_FILE")/configs" ]]; then
        local backup_dir="$(dirname "$SYSTEM_CONFIG_FILE")/configs.backup.$(date +%s)"
        cp -r "$(dirname "$SYSTEM_CONFIG_FILE")/configs" "$backup_dir" 2>/dev/null || true
    fi
    return 0
}

# Export functions
export -f setup_server
export -f update_packages_config
export -f update_system_type
export -f backup_config

# Check script execution
check_script_execution "SYSTEM_CONFIG_FILE" "setup_server $*"
