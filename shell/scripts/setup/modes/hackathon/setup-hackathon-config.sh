#!/usr/bin/env bash

# Helper to update hosting-config.nix
update_hosting_config() {
    local config_file="$(dirname "$SYSTEM_CONFIG_FILE")/configs/hosting-config.nix"
    local email_value="$1"
    local domain_value="$2"
    
    # Create configs directory if it doesn't exist
    mkdir -p "$(dirname "$config_file")"
    
    # Write hosting-config.nix
    cat > "$config_file" <<EOF
{
  email = "$email_value";
  domain = "$domain_value";
}
EOF
}

# Helper to update system-config.nix (only users and systemType)
update_system_config() {
    local temp_file=$(mktemp)
    local users_block="$1"
    local system_type="$2"
    
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
    
    # Update users block
    # Remove existing users block
    awk '
    BEGIN { skip = 0; }
    /^  users = {/ { skip = 1; next; }
    /^  };/ { if (skip) { skip = 0; next; } }
    { if (!skip) print; }
    ' "$temp_file" > "${temp_file}.tmp"
    mv "${temp_file}.tmp" "$temp_file"
    
    # Insert new users block before timeZone
    if grep -q "timeZone" "$temp_file"; then
        sed -i "/timeZone = /i\\  users = {\n$users_block\n  };" "$temp_file"
    else
        # Append at end before closing brace
        sed -i '$ i\  users = {\n'"$users_block"'\n  };' "$temp_file"
    fi
    
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

setup_hackathon_config() {
    log_section "Hackathon Configuration"

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

get_admin_username() {
    local default_user="$1"
    local username
    while true; do
        read -ep $'\033[0;34m[?]\033[0m Enter admin username'"${default_user:+ [$default_user]}"': ' username
        username="${username:-$default_user}"
        if [[ -n "$username" ]]; then
            echo "$username"
            return 0
        fi
        log_error "Username cannot be empty"
    done
}

get_email() {
    local default_email="$1"
    local email
    while true; do
        read -ep $'\033[0;34m[?]\033[0m Enter main email address'"${default_email:+ [$default_email]}"': ' email
        email="${email:-$default_email}"
        if [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            echo "$email"
            return 0
        fi
        log_error "Invalid email format"
    done
}

get_domain() {
    local default_domain="$1"
    local domain
    while true; do
        read -ep $'\033[0;34m[?]\033[0m Enter domain (e.g., example.com)'"${default_domain:+ [$default_domain]}"': ' domain
        domain="${domain:-$default_domain}"
        if [[ "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
            echo "$domain"
            return 0
        fi
        log_error "Invalid domain format"
    done
}

update_hackathon_config() {
    # Build users block
    local users_block="    \"$admin_user\" = {
      role = \"admin\";
      defaultShell = \"zsh\";
      autoLogin = false;
    };"
    
    # Update system-config.nix (users and systemType)
    update_system_config "$users_block" "hackathon" || return 1
    
    # Update hosting-config.nix (email and domain)
    update_hosting_config "$email" "$domain" || return 1
    
    return 0
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
export -f update_hosting_config
export -f update_system_config
export -f get_admin_username
export -f get_email
export -f get_domain
