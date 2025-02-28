#!/usr/bin/env bash

# Validate required variables
if [[ -z "${SYSTEM_CONFIG_FILE:-}" ]]; then
    echo "Error: SYSTEM_CONFIG_FILE not set"
    return 1
fi

check_user_passwords() {
    log_section "Checking User Configuration"
    
    # Directories
    local PASSWORD_DIR="build/secrets/passwords"
    ensure_dir "$PASSWORD_DIR"
    
    # Get users
    local current_users=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $1 !~ /^nixbld/ && $1 !~ /^systemd-/ {print $1}')
    local configured_users=$(awk '/users = {/,/};/ {if ($1 ~ /".*"/) print $1}' "$SYSTEM_CONFIG_FILE" | tr -d '"')
    
    # Debug info
    log_info "Current system users: $current_users"
    log_info "Configured users: $configured_users"
    
    # Process each user
    for user in $current_users; do
        local user_dir="$PASSWORD_DIR/$user"
        local password_file="$user_dir/.hashedPassword"
        
        if [ -f "$password_file" ]; then
            log_info "Found existing password for $user"
            continue
        fi
        
        log_warn "No stored password found for $user"
        ensure_dir "$user_dir"
        
        # Get and store password hash if exists
        if getent shadow "$user" | cut -d: -f2 | grep -q '[^!*]'; then
            getent shadow "$user" | cut -d: -f2 > "$password_file"
            chmod 600 "$password_file"
            log_success "Stored existing password for $user"
        fi
    done
    
    log_success "Password collection complete"
    return 0
}

# Export function
export -f check_user_passwords

# Check script execution
check_script_execution "SYSTEM_CONFIG_FILE" "check_user_passwords"