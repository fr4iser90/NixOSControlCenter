#!/usr/bin/env bash

setup_homelab_config() {
    log_section "Homelab Configuration"


    declare -g virt_password=""   
    # Initialize variables with existing data
    admin_user="$(logname)"
    virt_user="${VIRT_USER:-}"
    email="${HOST_EMAIL:-}"
    domain="${HOST_DOMAIN:-}"
    enable_desktop="${ENABLE_DESKTOP:-true}" 

    # Optional: Debug output
    echo "Debug: Admin user set to: ${admin_user}"
    
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

    # Virtualization user password
    get_virt_password  # Direkt aufrufen, nicht in Subshell
    local pw_result=$?
    if [[ $pw_result -ne 0 ]]; then
        return 1
    fi
    
    # Validate usernames
    if [[ "$admin_user" == "$virt_user" ]]; then
        log_error "Admin user and virtualization user cannot be the same!"
        return 1
    fi
    
    # Email configuration
    email=$(get_email "$email") || return 1
    
    # Domain configuration
    domain=$(get_domain "$domain") || return 1
        
    # Desktop configuration
    enable_desktop=$(get_desktop_enabled "$enable_desktop") || return 1  # <- HIER

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
    read -ep $'\033[0;34m[?]\033[0m Enter virtualization username(docker)'"${default_user:+ [$default_user]}"': ' username
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

update_homelab_config() {
    # Create temp file
    local temp_file=$(mktemp)
    cp "$SYSTEM_CONFIG_FILE" "$temp_file" || return 1
    
    # Hash password and create password file
    if ! create_password_file; then
        log_error "Failed to create password file"
        rm "$temp_file"
        return 1
    fi
    
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

get_virt_password() {
    log_section "Password Generation Virtualization User"
    local random_hex
    if ! random_hex=$(openssl rand -hex 4 2>/dev/null); then
        # Fallback wenn openssl fehlschlägt
        random_hex=$(head -c 8 /dev/urandom | xxd -p)
    fi

    if [[ -z "$random_hex" ]]; then
        log_error "Failed to generate random hex"
        return 1
    fi

    # Generiere ein garantiert valides Standardpasswort
    local default_password="P@ssw0rd-${random_hex}"
    local password
    
    echo -e "\033[0;36m----------------------------------------\033[0m"
    echo -e "\033[0;36mIMPORTANT PASSWORD INFORMATION\033[0m"
    echo -e "\033[0;36m----------------------------------------\033[0m"
    echo -e "\033[0;36mRandom password will be: $default_password\033[0m"
    echo -e "\033[0;36m\033[0m"
    echo -e "\033[0;36m!!! PLEASE NOTE !!!\033[0m"
    echo -e "\033[0;36m1. Change this password after first login!\033[0m"
    echo -e "\033[0;36m2. Password file location: /etc/nixos/secrets/passwords/${virt_user}/.hashedPassword\033[0m"
    echo -e "\033[0;36m3. Password Manager will be implemented soon\033[0m"
    echo -e "\033[0;36m----------------------------------------\033[0m"
    
    while true; do
        read -esp $'\033[0;34m[?]\033[0m Enter custom password (or press enter for random): ' password
        echo

        # Wenn Enter gedrückt wurde, nutze Zufallspasswort
        if [[ -z "$password" ]]; then
            log_success "Using random password"
            virt_password="$default_password"
            return 0
        fi

        # Prüfe Passwortlänge
        if [[ "${#password}" -lt 8 ]]; then
            log_error "Password must be at least 8 characters"
            sleep 1
            continue
        fi

        # Bestätigung des Passworts
        read -esp $'\033[0;34m[?]\033[0m Confirm password: ' password_confirm
        echo

        if [[ "$password" != "$password_confirm" ]]; then
            log_error "Passwords do not match!"
            sleep 1
            continue
        fi
        
        log_success "Using custom password"
        virt_password="$password"
        return 0
    done
}

create_password_file() {
    # Debug output
    echo "Debug: Creating password file for user: ${virt_user}"
    
    # Check if password is set
    if [[ -z "${virt_password}" ]]; then
        log_error "No password set for virtualization user"
        return 1
    fi

    # Check if mkpasswd is available
    if ! command -v mkpasswd >/dev/null 2>&1; then
        log_error "mkpasswd command not found. Installing whois package..."
        if ! sudo nix-env -iA nixos.whois; then
            log_error "Failed to install whois package"
            return 1
        fi
    fi

    # Create password directory
    local password_dir="/etc/nixos/secrets/passwords/${virt_user}"
    echo "Debug: Creating directory: ${password_dir}"
    if ! sudo mkdir -p "${password_dir}"; then
        log_error "Failed to create password directory: ${password_dir}"
        return 1
    fi

    # Hash password and save to file
    local password_file="${password_dir}/.hashedPassword"
    echo "Debug: Creating password file: ${password_file}"
    if ! echo "${virt_password}" | mkpasswd -m sha-512 --stdin | sudo tee "${password_file}" > /dev/null; then
        log_error "Failed to create password hash file: ${password_file}"
        return 1
    fi

    # Set correct permissions
    if ! sudo chmod 600 "${password_file}"; then
        log_error "Failed to set password file permissions"
        return 1
    fi

    if ! sudo chown root:root "${password_file}"; then
        log_error "Failed to set password file ownership"
        return 1
    fi

    log_success "Password file created successfully at ${password_file}"
    return 0
}

get_desktop_enabled() {
    local default_enabled="${1:-true}"
    local response
    
    while true; do
        read -ep $'\033[0;34m[?]\033[0m Enable desktop environment ("no" is still buggy, need to restart after build)? (y/n) ' response
        response="${response:-${default_enabled}}"
        
        case "${response,,}" in
            y|yes|true)
                echo "true"
                return 0
                ;;
            n|no|false)
                echo "false"
                return 0
                ;;
            *)
                log_error "Please answer yes or no"
                ;;
        esac
    done
}

update_desktop_enabled() {
    local config_file="$1"
    local enable_desktop="$2"
    
    sed -i "s/enableDesktop = .*\;/enableDesktop = ${enable_desktop};/" "$config_file"

}

update_users_homelab_block() {
    local config_file="$1"
    
    # Create a temporary file
    local temp_file="${config_file}.tmp"
    
    # First, remove any existing users blocks (including malformed ones)
    awk '
    BEGIN { skip = 0; }
    /^  users = {/ { skip = 1; next; }
    /^  };/ { if (skip) { skip = 0; next; } }
    /^  #[ ]*$/ { next; }
    { if (!skip) print; }
    ' "$config_file" > "$temp_file"
    
    # Now insert our new users block at the right position
    awk -v admin_user="$admin_user" -v virt_user="$virt_user" '
    /^  # User Management$/ {
        print;
        print "  users = {";
        print "    \"" admin_user "\" = {";
        print "      role = \"admin\";";
        print "      defaultShell = \"zsh\";";
        print "      autoLogin = false;";
        print "    };";
        if (virt_user != "") {
            print "    \"" virt_user "\" = {";
            print "      role = \"virtualization\";";
            print "      defaultShell = \"zsh\";";
            print "      autoLogin = true;";
            print "    };";
        }
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
    sed -i "s/systemType = \".*\";/systemType = \"homelab\";/" "$config_file"
}




export_homelab_vars() {
    export SYSTEM_TYPE="homelab"
    export ADMIN_USER="$admin_user"
    export VIRT_USER="$virt_user"
    export HOMELAB_EMAIL="$email"
    export HOMELAB_DOMAIN="$domain"
}

# Export functions
export -f setup_homelab_config
export -f collect_homelab_info
export -f update_homelab_config
export -f get_admin_username
export -f get_virt_username
export -f get_email
export -f get_domain
export -f log_error
export -f log_success
export -f log_section
export -f setup_homelab_config
export -f update_users_homelab_block
export -f update_email_domain
export -f update_system_type
export -f export_homelab_vars
export -f create_password_file
export -f get_virt_password
