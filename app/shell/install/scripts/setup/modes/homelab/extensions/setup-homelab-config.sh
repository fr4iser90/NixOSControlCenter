#!/usr/bin/env bash

setup_homelab_config() {
    log_section "Homelab Configuration"
    log_debug "Starting homelab configuration..."

    
    # Initialize variables with existing data
    admin_user="${CURRENT_USER:-}"
    virt_user="${VIRT_USER:-}"
    email="${HOST_EMAIL:-}"
    domain="${HOST_DOMAIN:-}"
    cert_email="${CERT_EMAIL:-}"
    
    # Collect homelab information
    collect_homelab_info || return 1
    
    # Update system configuration
    update_homelab_config || return 1
    
    # Export variables for later use
    export_homelab_vars
    
    log_success "Homelab configuration complete"
    return 0
}

collect_homelab_info() {
    # Admin user
    admin_user=$(get_admin_username "$admin_user") || return 1
    
    # Virtualization user
    virt_user=$(get_virt_username "$virt_user") || return 1
    
    # Validate usernames
    if [[ "$admin_user" == "$virt_user" ]]; then
        log_error "Admin user and virtualization user cannot be the same!"
        return 1
    fi
    
    # Email configuration
    email=$(get_email "$email") || return 1
    
    # Domain configuration
    domain=$(get_domain "$domain") || return 1
    
    # SSL cert email
    cert_email=$(get_cert_email "$email" "$cert_email") || return 1
    
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

get_virt_username() {
    local default_user="$1"
    local username
    read -ep $'\033[0;34m[?]\033[0m Enter virtualization username'"${default_user:+ [$default_user]}"': ' username
    echo "${username:-${default_user:-docker}}"
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

get_cert_email() {
    local default_email="$1"
    local current_cert_email="$2"
    local cert_email
    read -ep $'\033[0;34m[?]\033[0m Enter SSL certificate email'"${current_cert_email:+ [$current_cert_email]}"': ' cert_email
    echo "${cert_email:-${current_cert_email:-$default_email}}"
}

update_homelab_config() {
    log_info "Updating homelab configuration"
    
    # Create temp file
    local temp_file=$(mktemp)
    cp "$SYSTEM_CONFIG_FILE" "$temp_file" || return 1
    
    # Update configurations
    update_users_homelab_block "$temp_file" || return 1
    update_email_domain "$temp_file" || return 1
    update_system_type "$temp_file" || return 1

    
    # Verify changes
    if diff "$SYSTEM_CONFIG_FILE" "$temp_file" >/dev/null; then
        log_error "Failed to update system configuration"
        rm "$temp_file"
        return 1
    fi
    
    # Apply changes
    sudo mv "$temp_file" "$SYSTEM_CONFIG_FILE" || return 1
    
    return 0
}

update_users_homelab_block() {
    local config_file="$1"
    
    awk -v admin_user="$admin_user" -v virt_user="$virt_user" '
    /^  users = {/,/^  };/ {
        if ($0 ~ /^  users = {/) {
            print "  users = {"
            print "    \"" admin_user "\" = {"
            print "      role = \"admin\";"
            print "      defaultShell = \"zsh\";"
            print "      autoLogin = false;"
            print "    };"
            if (virt_user != "") {
                print "    \"" virt_user "\" = {"
                print "      role = \"virtualization\";"
                print "      defaultShell = \"zsh\";"
                print "      autoLogin = false;"
                print "    };"
            }
            print "  };"
            next
        }
    }
    { print }
    ' "$config_file" > "${config_file}.new" && mv "${config_file}.new" "$config_file"
}

update_email_domain() {
    local config_file="$1"
    
    if ! grep -q "email =" "$config_file"; then
        sed -i "/^{/a\\  email = \"${email}\";\n  domain = \"${domain}\";\n  certEmail = \"${cert_email}\";" "$config_file"
    else
        sed -i \
            -e "s/email = \".*\";/email = \"${email}\";/" \
            -e "s/domain = \".*\";/domain = \"${domain}\";/" \
            -e "s/certEmail = \".*\";/certEmail = \"${cert_email}\";/" \
            "$config_file"
    fi
}

update_system_type() {
    local config_file="$1"
    sed -i "s/systemType = \".*\";/systemType = \"homelab\";/" "$config_file"
}



export_homelab_vars() {
    export ADMIN_USER="$admin_user"
    export VIRT_USER="$virt_user"
    export HOMELAB_EMAIL="$email"
    export HOMELAB_DOMAIN="$domain"
    export HOMELAB_CERT_EMAIL="$cert_email"
}

# Export functions
export -f setup_homelab_config
export -f collect_homelab_info
export -f update_homelab_config
export -f get_admin_username
export -f get_virt_username
export -f get_email
export -f get_domain
export -f get_cert_email
export -f update_users_homelab_block
export -f update_email_domain
export -f update_system_type
export -f export_homelab_vars