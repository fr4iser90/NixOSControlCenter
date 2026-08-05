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
    local homelab_type="${3:-single}"
    
    # Write users to modular config location
    write_user_config "$users_block"
    
    # Write homelab config if swarm role is set
    if [[ "$system_type" == "server" ]]; then
        write_system_manager_config "$system_type" "false" "stable" "systemd-boot"
    fi
    
    if [[ "$homelab_type" == "swarm" ]]; then
        write_homelab_config "swarm" "true" "false" "${swarm_role:-manager}"
    else
        write_homelab_config "single" "true" "false"
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
    
    # Homelab type selection (Single-Server vs Multi-Server)
    local homelab_type=$(get_homelab_type) || return 1
    
    # Swarm role selection (only if Multi-Server)
    if [[ "$homelab_type" == "swarm" ]]; then
        swarm_role=$(get_swarm_role) || return 1
    else
        swarm_role="none"
    fi
    declare -g swarm_role="$swarm_role"
    
    # Docker mode detection (for user setup default)
    docker_mode=$(detect_docker_mode) || docker_mode="docker"
    
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
        # Normalize: Homelab uses yes/no; custom setup may return extra/main
        case "${use_extra_user,,}" in
            y|yes|true|extra) use_extra_user="yes" ;;
            *) use_extra_user="no" ;;
        esac
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

    if username=$(ncc_gui_answer ADMIN_USER 2>/dev/null); then
        echo "$username"
        return 0
    fi
    if declare -F ncc_install_ui_prefer_gui >/dev/null 2>&1 && ncc_install_ui_prefer_gui; then
        username=$(ncc_gui_ask text "Admin user" "Enter admin username" "$default_user") || return 1
        echo "${username:-$default_user}"
        return 0
    fi

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

    if username=$(ncc_gui_answer VIRT_USER 2>/dev/null); then
        echo "$username"
        return 0
    fi
    if declare -F ncc_install_ui_prefer_gui >/dev/null 2>&1 && ncc_install_ui_prefer_gui; then
        username=$(ncc_gui_ask text "Virtualization user" "Enter virtualization username (docker)" "${default_user:-docker}") || return 1
        echo "${username:-${default_user:-docker}}"
        return 0
    fi

    read -ep $'\033[0;34m[?]\033[0m Enter virtualization username(docker)'"${default_user:+ [$default_user]}"': ' username
    echo "${username:-${default_user:-docker}}"
}

get_homelab_type() {
    local response
    local default_response="n"
    local from_gui

    if from_gui=$(ncc_gui_answer HOMELAB_TYPE 2>/dev/null); then
        echo "$from_gui"
        return 0
    fi
    if declare -F ncc_install_ui_prefer_gui >/dev/null 2>&1 && ncc_install_ui_prefer_gui; then
        response=$(ncc_gui_ask yesno "Homelab topology" "Use Multi-Server (Docker Swarm)?" "$default_response") || return 1
        case "$response" in
            y|yes) echo "swarm"; return 0 ;;
            *) echo "single"; return 0 ;;
        esac
    fi

    read -ep $'\033[0;34m[?]\033[0m Use Multi-Server (Docker Swarm)? (y/n)'" [${default_response}]: " response
    response="${response:-${default_response}}"
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    
    case "$response" in
        y|yes)
            echo "swarm"
            return 0
            ;;
        n|no)
            echo "single"
            return 0
            ;;
        *)
            log_error "Invalid response. Please enter 'y' or 'n'."
            return 1
            ;;
    esac
}

get_swarm_role() {
    local selected
    local from_gui

    if from_gui=$(ncc_gui_answer SWARM_ROLE 2>/dev/null); then
        echo "$from_gui"
        return 0
    fi
    if declare -F ncc_install_ui_prefer_gui >/dev/null 2>&1 && ncc_install_ui_prefer_gui; then
        selected=$(ncc_gui_ask choice "Swarm role" "Select Swarm role" "Manager|Worker" "Manager") || return 1
        case "$selected" in
            Manager|manager) echo "manager"; return 0 ;;
            Worker|worker) echo "worker"; return 0 ;;
            *) log_error "Invalid selection"; return 1 ;;
        esac
    fi

    selected=$(printf "%s\n" "Manager" "Worker" | fzf \
        --header="Select Swarm role" \
        --height=8 \
        --pointer="▶" \
        --marker="✓" \
        --select-1) || {
        log_error "Selection cancelled"
        return 1
    }
    
    case "$selected" in
        "Manager")
            echo "manager"
            return 0
            ;;
        "Worker")
            echo "worker"
            return 0
            ;;
        *)
            log_error "Invalid selection"
            return 1
            ;;
    esac
}

detect_docker_mode() {
    # Check packages config for docker feature (v1 modular location)
    local packages_config="$(dirname "$SYSTEM_CONFIG_FILE")/systemConfig/core/base/packages/config.nix"
    if [[ -f "$packages_config" ]]; then
        if grep -q '"docker"' "$packages_config"; then
            echo "docker"
            return 0
        fi
    fi
    # Default to docker
    echo "docker"
    return 0
}

get_docker_user_setup() {
    local docker_mode="$1"  # "docker" (wird automatisch rootless oder root entschieden)
    local default_response
    local from_gui
    local response

    if from_gui=$(ncc_gui_answer USE_EXTRA_USER 2>/dev/null) \
        || from_gui=$(ncc_gui_answer DOCKER_USER_SETUP 2>/dev/null); then
        case "${from_gui,,}" in
            y|yes|true|extra) echo "yes"; return 0 ;;
            n|no|false|main) echo "no"; return 0 ;;
        esac
    fi

    # Determine default based on Docker mode
    if [[ "$docker_mode" == "docker" ]]; then
        default_response="y"  # Root Docker → Extra User (default)
    else
        default_response="n"  # Rootless Docker → Main User (default)
    fi

    if declare -F ncc_install_ui_prefer_gui >/dev/null 2>&1 && ncc_install_ui_prefer_gui; then
        response=$(ncc_gui_ask yesno "Docker user" "Use separate user for Docker?" "$default_response") || return 1
        case "${response,,}" in
            y|yes) echo "yes"; return 0 ;;
            *) echo "no"; return 0 ;;
        esac
    fi

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

    if email=$(ncc_gui_answer EMAIL 2>/dev/null); then
        echo "$email"
        return 0
    fi
    if declare -F ncc_install_ui_prefer_gui >/dev/null 2>&1 && ncc_install_ui_prefer_gui; then
        while true; do
            email=$(ncc_gui_ask text "Email" "Enter main email address" "$default_email") || return 1
            email="${email:-$default_email}"
            if [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
                echo "$email"
                return 0
            fi
            log_error "Invalid email format"
        done
    fi

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

    if domain=$(ncc_gui_answer DOMAIN 2>/dev/null); then
        echo "$domain"
        return 0
    fi
    if declare -F ncc_install_ui_prefer_gui >/dev/null 2>&1 && ncc_install_ui_prefer_gui; then
        while true; do
            domain=$(ncc_gui_ask text "Domain" "Enter domain (e.g., example.com)" "$default_domain") || return 1
            domain="${domain:-$default_domain}"
            if [[ "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
                echo "$domain"
                return 0
            fi
            log_error "Invalid domain format"
        done
    fi

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
    
    # Pass type token expected by update_system_config (single|swarm)
    local homelab_type="single"
    if [[ "$swarm_role" != "none" ]]; then
        homelab_type="swarm"
    fi

    # Update modular configs (users, systemType, homelab)
    update_system_config "$users_block" "server" "$homelab_type" || return 1
    
    # Update hosting config (email and domain)
    update_hosting_config "$email" "$domain" || return 1
    
    # Package modules: GUI selection, else Homelab defaults
    local hl_defaults="${PRESET_DEFAULT_PACKAGES[Homelab Server]:-docker database web-server}"
    if [[ "$enable_desktop" != "false" ]]; then
        # Ensure a browser when desktop is on and GUI did not set BROWSERS
        if declare -F ncc_gui_answer >/dev/null 2>&1; then
            if ! ncc_gui_answer BROWSERS >/dev/null 2>&1; then
                export PACKAGE_SYSTEM_PACKAGES="${PACKAGE_SYSTEM_PACKAGES:-firefox}"
            fi
        else
            export PACKAGE_SYSTEM_PACKAGES="${PACKAGE_SYSTEM_PACKAGES:-firefox}"
        fi
    fi
    if declare -F ncc_apply_gui_package_modules >/dev/null 2>&1; then
        ncc_apply_gui_package_modules "$hl_defaults" || return 1
    else
        # shellcheck disable=SC2206
        local arr=($hl_defaults)
        write_packages_config "${arr[@]}" || return 1
    fi
    unset PACKAGE_SYSTEM_PACKAGES 2>/dev/null || true

    # Update desktop config if desktop setting is needed
    if [[ "$enable_desktop" == "false" ]]; then
        write_desktop_disabled || return 1
    else
        write_desktop_config "plasma" "sddm" "wayland" "plasma" "true" "pipewire" || return 1
        write_audio_config "pipewire" || return 1
    fi
    
    return 0
}

get_virt_password() {
    log_section "Password Generation Virtualization User"
    local random_hex
    local from_gui
    local password
    local default_password

    if from_gui=$(ncc_gui_answer VIRT_PASSWORD 2>/dev/null); then
        virt_password="$from_gui"
        log_success "Using password from GUI wizard"
        return 0
    fi

    if ! random_hex=$(openssl rand -hex 4 2>/dev/null); then
        random_hex=$(head -c 8 /dev/urandom | xxd -p)
    fi

    if [[ -z "$random_hex" ]]; then
        log_error "Failed to generate random hex"
        return 1
    fi

    default_password="P@ssw0rd-${random_hex}"

    if declare -F ncc_install_ui_prefer_gui >/dev/null 2>&1 && ncc_install_ui_prefer_gui; then
        password=$(ncc_gui_ask password "Virt user password" \
            "Enter password for virtualization user (or leave empty for random)." \
            "Suggested: $default_password") || return 1
        if [[ -z "$password" ]]; then
            virt_password="$default_password"
            log_success "Using random password"
        else
            virt_password="$password"
            log_success "Using custom password"
        fi
        return 0
    fi

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

        if [[ -z "$password" ]]; then
            log_success "Using random password"
            virt_password="$default_password"
            return 0
        fi

        if [[ "${#password}" -lt 8 ]]; then
            log_error "Password must be at least 8 characters"
            sleep 1
            continue
        fi

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

    local secrets_root="${SYSTEM_CONFIG_DIR:-/etc/nixos}/secrets/passwords"
    local password_dir="${secrets_root}/${virt_user}"
    local password_file="${password_dir}/.hashedPassword"
    local use_sudo=0
    [[ "${SYSTEM_CONFIG_DIR:-/etc/nixos}" == "/etc/nixos" ]] && use_sudo=1

    if declare -F ncc_dry_run >/dev/null 2>&1 && ncc_dry_run; then
        ncc_dry_skip "create password file" "$password_file" \
            "(password length=${#virt_password}, hashing skipped)"
        return 0
    fi

    # Check if mkpasswd is available
    if ! command -v mkpasswd >/dev/null 2>&1; then
        log_error "mkpasswd command not found. Installing whois package..."
        if ! sudo nix-env -iA nixos.whois; then
            log_error "Failed to install whois package"
            return 1
        fi
    fi

    echo "Debug: Creating directory: ${password_dir}"
    if [[ $use_sudo -eq 1 ]]; then
        sudo mkdir -p "${password_dir}" || {
            log_error "Failed to create password directory: ${password_dir}"
            return 1
        }
    else
        mkdir -p "${password_dir}" || {
            log_error "Failed to create password directory: ${password_dir}"
            return 1
        }
    fi

    echo "Debug: Creating password file: ${password_file}"
    if [[ $use_sudo -eq 1 ]]; then
        if ! echo "${virt_password}" | mkpasswd -m sha-512 --stdin | sudo tee "${password_file}" > /dev/null; then
            log_error "Failed to create password hash file: ${password_file}"
            return 1
        fi
        sudo chmod 600 "${password_file}" || {
            log_error "Failed to set password file permissions"
            return 1
        }
        sudo chown root:root "${password_file}" || {
            log_error "Failed to set password file ownership"
            return 1
        }
    else
        if ! echo "${virt_password}" | mkpasswd -m sha-512 --stdin > "${password_file}"; then
            log_error "Failed to create password hash file: ${password_file}"
            return 1
        fi
        chmod 600 "${password_file}" || true
    fi

    log_success "Password file created successfully at ${password_file}"
    return 0
}

get_desktop_enabled() {
    local default_enabled="${1:-true}"
    local response
    local from_gui

    if from_gui=$(ncc_gui_answer ENABLE_DESKTOP 2>/dev/null); then
        echo "$from_gui"
        return 0
    fi
    if declare -F ncc_install_ui_prefer_gui >/dev/null 2>&1 && ncc_install_ui_prefer_gui; then
        local def="y"
        [[ "$default_enabled" == "false" || "$default_enabled" == "n" ]] && def="n"
        response=$(ncc_gui_ask yesno "Desktop" \
            'Enable desktop environment? ("no" is still buggy, may need restart after build)' \
            "$def") || return 1
        case "${response,,}" in
            y|yes) echo "true"; return 0 ;;
            *) echo "false"; return 0 ;;
        esac
    fi

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
export -f get_homelab_type
export -f get_swarm_role
export -f detect_docker_mode
export -f get_docker_user_setup
export -f export_homelab_vars
export -f create_password_file
export -f get_virt_password
export -f update_hosting_config
export -f update_system_config
export -f get_desktop_enabled
