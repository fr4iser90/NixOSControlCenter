#!/usr/bin/env bash

setup_hackathon_config() {
    log_section "Hackathon Server Configuration"

    # Initialize variables with existing data
    admin_user="$(logname)"
    email="${HOST_EMAIL:-}"
    domain="${HOST_DOMAIN:-}"
    
    # Collect hackathon information
    collect_hackathon_info || return 1
    
    # Update system configuration
    update_hackathon_config || return 1
    
    # Export variables for later use
    export_hackathon_vars
    
    log_success "Hackathon configuration complete"
    return 0
}

collect_hackathon_info() {
    # Admin user
    admin_user=$(get_admin_username "$admin_user") || return 1
    
    # Email configuration
    email=$(get_email "$email") || return 1
    
    # Domain configuration
    domain=$(get_domain "$domain") || return 1
    
    return 0
}

update_hackathon_config() {
    # Create temp file
    local temp_file=$(mktemp)
    cp "$SYSTEM_CONFIG_FILE" "$temp_file" || return 1
    
    # Update configurations
    update_users_hackathon_block "$temp_file" || return 1
    update_email_domain "$temp_file" || return 1
    update_system_type "$temp_file" || return 1
    
    # Verify changes
    if diff "$SYSTEM_CONFIG_FILE" "$temp_file" >/dev/null; then
        log_error "Failed to update system configuration"
        rm "$temp_file"
        return 1
    fi
    
    # Apply changes
    if [[ -w "$SYSTEM_CONFIG_FILE" ]]; then
        mv "$temp_file" "$SYSTEM_CONFIG_FILE"
    else
        if command -v sudo >/dev/null 2>&1; then
            sudo mv "$temp_file" "$SYSTEM_CONFIG_FILE"
        else
            if command -v doas >/dev/null 2>&1; then
                doas mv "$temp_file" "$SYSTEM_CONFIG_FILE"
            else
                log_error "Cannot write to $SYSTEM_CONFIG_FILE (no sudo/doas available)"
                rm "$temp_file"
                return 1
            fi
        fi
    fi
    
    return 0
}

update_users_hackathon_block() {
    local config_file="$1"
    
    # Create a temporary file
    local temp_file="${config_file}.tmp"
    
    # First, remove any existing users blocks
    awk '
    BEGIN { skip = 0; }
    /^  users = {/ { skip = 1; next; }
    /^  };/ { if (skip) { skip = 0; next; } }
    /^  #[ ]*$/ { next; }
    { if (!skip) print; }
    ' "$config_file" > "$temp_file"
    
    # Now insert our new users block
    awk -v admin_user="$admin_user" '
    /^  # User Management$/ {
        print;
        print "  users = {";
        print "    \"" admin_user "\" = {";
        print "      role = \"admin\";";
        print "      defaultShell = \"zsh\";";
        print "      autoLogin = false;";
        print "    };";
        print "  };";
        next;
    }
    { print }
    ' "$temp_file" > "${config_file}.new"
    
    # Apply changes
    mv "${config_file}.new" "$config_file"
    rm -f "$temp_file"
}

update_email_domain() {
    local config_file="$1"
    
    if ! grep -q "email =" "$config_file"; then
        sed -i "/^{/a\\  email = \"${email}\";\n  domain = \"${domain}\";" "$config_file"
    else
        sed -i \
            -e "s/email = \".*\";/email = \"${email}\";/" \
            -e "s/domain = \".*\";/domain = \"${domain}\";/" \
            "$config_file"
    fi
}

update_system_type() {
    local config_file="$1"
    sed -i "s/systemType = \".*\";/systemType = \"hackathon\";/" "$config_file"
}

export_hackathon_vars() {
    export SYSTEM_TYPE="hackathon"
    export ADMIN_USER="$admin_user"
    export HACKATHON_EMAIL="$email"
    export HACKATHON_DOMAIN="$domain"
}

# Export functions
export -f setup_hackathon_config
export -f collect_hackathon_info
export -f update_hackathon_config
export -f update_users_hackathon_block
export -f update_email_domain
export -f update_system_type
export -f export_hackathon_vars 