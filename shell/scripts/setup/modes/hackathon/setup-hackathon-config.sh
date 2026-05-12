#!/usr/bin/env bash

# Helper to update hosting config (v1)
update_hosting_config() {
    local email_value="$1"
    local domain_value="$2"
    write_hosting_config "$email_value" "$domain_value"
}

# Helper to update system config with users (v1)
update_system_config() {
    local users_block="$1"
    local system_type="$2"
    
    write_user_config "$users_block"
    
    write_system_manager_config "$system_type" "false" "stable" "systemd-boot"
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
    
    log_success "Hackathon configuration complete (v1 modular)"
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
    
    # Update system config (users and systemType)
    update_system_config "$users_block" "hackathon" || return 1
    
    # Update hosting config (email and domain)
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
