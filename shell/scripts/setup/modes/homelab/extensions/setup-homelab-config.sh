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

# Helper to update system-config.nix (users, systemType, and homelab block)
update_system_config() {
    local temp_file=$(mktemp)
    local users_block="$1"
    local system_type="$2"
    local homelab_block="${3:-}"
    
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
    
    # Remove existing homelab block if present
    awk '
    BEGIN { skip = 0; }
    /^  homelab = {/ { skip = 1; next; }
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
    
    # Insert homelab block after users block (if provided)
    if [[ -n "$homelab_block" ]]; then
        if grep -q "users = {" "$temp_file"; then
            sed -i "/^  };$/a\\$homelab_block" "$temp_file"
        else
            sed -i '$ i\'"$homelab_block" "$temp_file"
        fi
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

setup_homelab_config() {
    log_section "Homelab Configuration"

    declare -g virt_password=""
    declare -g swarm_role="none"
    declare -g use_extra_user="no"
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
    
    # Swarm role selection
    swarm_role=$(get_swarm_role) || return 1
    declare -g swarm_role="$swarm_role"
    
    # Docker mode detection (for user setup default)
    docker_mode=$(detect_docker_mode) || docker_mode="docker-rootless"
    
    # User setup: Extra User vs Main User
    if [[ "$swarm_role" != "none" ]]; then
        # Swarm requires Extra User
        use_extra_user="yes"
        declare -g use_extra_user="$use_extra_user"
        virt_user=$(get_virt_username "$virt_user") || return 1
        get_virt_password || return 1
        if [[ "$admin_user" == "$virt_user" ]]; then
            log_error "Admin user and virtualization user cannot be the same!"
            return 1
        fi
    else
        # Single-Server: Ask for user setup
        use_extra_user=$(get_docker_user_setup "$docker_mode") || return 1
        declare -g use_extra_user="$use_extra_user"
        if [[ "$use_extra_user" == "yes" ]]; then
            virt_user=$(get_virt_username "$virt_user") || return 1
            get_virt_password || return 1
            if [[ "$admin_user" == "$virt_user" ]]; then
                log_error "Admin user and virtualization user cannot be the same!"
                return 1
            fi
        else
            # Use main user as admin (no extra user)
            virt_user=""
        fi
    fi
    
    # Email configuration
    email=$(get_email "$email") || return 1
    
    # Domain configuration
    domain=$(get_domain "$domain") || return 1
        
    # Desktop configuration
    enable_desktop=$(get_desktop_enabled "$enable_desktop") || return 1

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

get_swarm_role() {
    local response
    while true; do
        read -ep $'\033[0;34m[?]\033[0m Docker Swarm setup? (none/manager/worker) [none]: ' response
        response="${response:-none}"
        
        case "${response,,}" in
            none|"")
                echo "none"
                return 0
                ;;
            manager)
                echo "manager"
                return 0
                ;;
            worker)
                echo "worker"
                return 0
                ;;
            *)
                log_error "Please answer: none, manager, or worker"
                ;;
        esac
    done
}

detect_docker_mode() {
    # Check packages-config.nix for docker feature
    local packages_config="$(dirname "$SYSTEM_CONFIG_FILE")/configs/packages-config.nix"
    if [[ -f "$packages_config" ]]; then
        if grep -q '"docker"' "$packages_config"; then
            echo "docker"
            return 0
        elif grep -q '"docker-rootless"' "$packages_config"; then
            echo "docker-rootless"
            return 0
        fi
    fi
    # Default to docker-rootless
    echo "docker-rootless"
    return 0
}

get_docker_user_setup() {
    local docker_mode="$1"  # "docker" or "docker-rootless"
    local default_response
    
    # Determine default based on Docker mode
    if [[ "$docker_mode" == "docker" ]]; then
        default_response="y"  # Root Docker → Extra User (default)
    else
        default_response="n"  # Rootless Docker → Main User (default)
    fi
    
    local response
    while true; do
        read -ep $'\033[0;34m[?]\033[0m Use separate user for Docker? (y/n)'" [${default_response}]: " response
        response="${response:-${default_response}}"
        
        case "${response,,}" in
            y|yes)
                echo "yes"
                return 0
                ;;
            n|no)
                echo "no"
                return 0
                ;;
            *)
                log_error "Please answer yes or no"
                ;;
        esac
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

update_homelab_config() {
    # Hash password and create password file (only if extra user)
    if [[ -n "$virt_user" ]]; then
        if ! create_password_file; then
            log_error "Failed to create password file"
            return 1
        fi
    fi
    
    # Build users block
    local users_block="    \"$admin_user\" = {
      role = \"admin\";
      defaultShell = \"zsh\";
      autoLogin = false;
    };"
    
    if [[ -n "$virt_user" ]]; then
        users_block="$users_block
    \"$virt_user\" = {
      role = \"virtualization\";
      defaultShell = \"zsh\";
      autoLogin = true;
    };"
    fi
    
    # Build homelab block (if Swarm or Single-Server)
    local homelab_block=""
    if [[ "$swarm_role" != "none" ]]; then
        homelab_block="  homelab = {
    swarm = {
      role = \"$swarm_role\";
    };
  };"
    else
        # Single-Server: homelab block without swarm
        homelab_block="  homelab = {};"
    fi
    
    # Update system-config.nix (users, systemType, and homelab block)
    update_system_config "$users_block" "server" "$homelab_block" || return 1
    
    # Update hosting-config.nix (email and domain)
    update_hosting_config "$email" "$domain" || return 1
    
    # Update desktop-config.nix if desktop setting is needed
    if [[ "$enable_desktop" == "false" ]]; then
        local desktop_config="$(dirname "$SYSTEM_CONFIG_FILE")/configs/desktop-config.nix"
        mkdir -p "$(dirname "$desktop_config")"
        cat > "$desktop_config" <<EOF
{
  desktop = {
    enable = false;
    environment = "plasma";
    display = {
      manager = "sddm";
      server = "wayland";
      session = "plasma";
    };
    theme = {
      dark = true;
    };
    audio = "pipewire";
  };
}
EOF
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

export_homelab_vars() {
    export SYSTEM_TYPE="server"
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
export -f get_swarm_role
export -f detect_docker_mode
export -f get_docker_user_setup
export -f log_error
export -f log_success
export -f log_section
export -f update_users_homelab_block
export -f update_email_domain
export -f update_system_type
export -f export_homelab_vars
export -f create_password_file
export -f get_virt_password
export -f update_hosting_config
export -f update_system_config
