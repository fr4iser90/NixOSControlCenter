#!/usr/bin/env bash

# Always run hardware config/partition check before anything else
if [[ -n "${CHECKS_DIR:-}" ]]; then
    source "$CHECKS_DIR/hardware/hardware-config.sh"
else
    "$(dirname "$0")"/../../checks/hardware/hardware-config.sh
fi

# Helper function to update packages
update_packages_config() {
    local module_args=("$@")
    if [[ ${#module_args[@]} -gt 0 ]]; then
        write_packages_config "${module_args[@]}" || return 1
    else
        write_packages_config || return 1
    fi
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
            chown root:root "$backup_root" 2>/dev/null || sudo chown root:root "$backup_root" 2>/dev/null || true
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

# Get Docker user setup preference
get_docker_user_setup() {
    local docker_mode="$1"
    local default_response="n"
    
    local response
    while true; do
        read -ep $'\033[0;34m[?]\033[0m Use separate user for Docker? (y/n)'" [${default_response}]: " response
        response="${response:-${default_response}}"
        
        case "${response,,}" in
            y|yes)
                echo "extra"
                return 0
                ;;
            n|no)
                echo "main"
                return 0
                ;;
            *)
                log_error "Please answer yes or no"
                ;;
        esac
    done
}

# Setup Docker users
setup_docker_users() {
    local user_setup_mode="$1"
    local docker_mode="$2"
    
    local main_user
    main_user="$(logname)"
    local virt_user=""
    local users_block=""
    
    if [[ "$user_setup_mode" == "extra" ]]; then
        read -ep $'\033[0;34m[?]\033[0m Enter virtualization username(docker) [docker]: ' virt_user
        virt_user="${virt_user:-docker}"
        
        users_block="    \"$main_user\" = {
      role = \"admin\";
      defaultShell = \"zsh\";
      autoLogin = false;
    };
    \"$virt_user\" = {
      role = \"virtualization\";
      defaultShell = \"zsh\";
      autoLogin = false;
    };"
    else
        users_block="    \"$main_user\" = {
      role = \"admin\";
      defaultShell = \"zsh\";
      autoLogin = false;
    };"
    fi
    
    write_user_config "$users_block" || return 1
    
    return 0
}

# Detect Docker features and setup users accordingly
detect_and_setup_docker_users() {
    local features=("$@")
    local docker_feature=""
    
    for feature in "${features[@]}"; do
        if [[ "$feature" == "docker" ]]; then
            docker_feature="docker"
            break
        fi
    done
    
    if [[ -z "$docker_feature" ]]; then
        return 0
    fi
    
    local swarm_role="none"
    local homelab_config="$(dirname "$SYSTEM_CONFIG_FILE")/systemConfig/modules/infrastructure/homelab-manager/config.nix"
    if [[ -f "$homelab_config" ]] && grep -q "homelab.*=.*true" "$homelab_config" 2>/dev/null; then
        if [[ -f "$SYSTEM_CONFIG_FILE" ]] && grep -q "homelab" "$SYSTEM_CONFIG_FILE" 2>/dev/null; then
            if grep -q 'role = "manager"' "$SYSTEM_CONFIG_FILE" 2>/dev/null; then
                swarm_role="manager"
            elif grep -q 'role = "worker"' "$SYSTEM_CONFIG_FILE" 2>/dev/null; then
                swarm_role="worker"
            fi
        fi
    fi
    
    if [[ "$swarm_role" != "none" ]]; then
        setup_docker_users "extra" "docker-rootless" || return 1
    else
        local use_extra_user
        use_extra_user=$(get_docker_user_setup "docker") || return 1
        setup_docker_users "$use_extra_user" "docker-rootless" || return 1
    fi
    
    return 0
}

setup_custom() {
    log_section "Custom Install"

    # Parse arguments: system_type feature1 feature2 ...
    local system_type="$1"
    shift
    local features=("$@")

    # Backup
    backup_config || return 1

    # Separate Desktop Environments from Package Features
    local desktop_env=""
    local package_features=()

    for feature in "${features[@]}"; do
        if [[ "$feature" =~ ^(plasma|gnome|xfce)$ ]]; then
            desktop_env="$feature"
        else
            package_features+=("$feature")
        fi
    done

    # Update desktop config if Desktop Environment selected
    if [[ -n "$desktop_env" ]]; then
        local display_mgr="sddm"
        local display_server="wayland"
        local session="$desktop_env"
        local dark_mode="true"
        local audio="pipewire"
        
        case "$desktop_env" in
            "plasma") display_mgr="sddm" ;;
            "gnome") display_mgr="gdm" ;;
            "xfce") display_mgr="lightdm" ;;
        esac
        
        write_desktop_config "$desktop_env" "$display_mgr" "$display_server" "$session" "$dark_mode" "$audio" || return 1
        write_audio_config "$audio" || return 1
    else
        # Desktop or server without DE
        if [[ "$system_type" == "desktop" ]]; then
            write_desktop_disabled || return 1
        fi
    fi

    # Update packages config
    if [[ ${#package_features[@]} -gt 0 ]]; then
        local package_modules_string="${package_features[*]}"
        read -ra mod_array <<< "$package_modules_string"
        update_packages_config "${mod_array[@]}" || return 1
    else
        update_packages_config || return 1
    fi

    # Check for Docker features and handle user setup
    detect_and_setup_docker_users "${package_features[@]}" || return 1

    # Export system type for deployment
    export SYSTEM_TYPE="$system_type"
    deploy_config

    log_success "Custom install complete (v1 modular)"
}

# Export functions
export -f setup_custom
export -f update_packages_config
export -f backup_config
export -f detect_and_setup_docker_users
export -f get_docker_user_setup
export -f setup_docker_users

# Check script execution and run
check_script_execution "SYSTEM_CONFIG_FILE" "setup_custom $*"
