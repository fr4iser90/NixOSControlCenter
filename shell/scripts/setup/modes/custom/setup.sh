#!/usr/bin/env bash

# Always run hardware config/partition check before anything else
if [[ -n "${CHECKS_DIR:-}" ]]; then
    source "$CHECKS_DIR/hardware/hardware-config.sh"
else
    # Fallback if CHECKS_DIR is not set
    "$(dirname "$0")"/../../checks/hardware/hardware-config.sh
fi

# Helper function to update packages-config.nix
update_packages_config() {
    local config_file="$(dirname "$SYSTEM_CONFIG_FILE")/configs/packages-config.nix"
    local package_modules="$1"
    
    # Create configs directory if it doesn't exist
    mkdir -p "$(dirname "$config_file")"
    
    # Build package modules list
    local modules_list=""
    if [[ -n "$package_modules" ]]; then
        # Convert space-separated string to array
        local modules_array=($package_modules)
        for module in "${modules_array[@]}"; do
            if [[ -n "$modules_list" ]]; then
                modules_list="${modules_list}\n    \"$module\""
            else
                modules_list="    \"$module\""
            fi
        done
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

# Helper: Update desktop-config.nix
update_desktop_config() {
    local desktop_env="$1"
    local config_file="$(dirname "$SYSTEM_CONFIG_FILE")/configs/desktop-config.nix"
    
    mkdir -p "$(dirname "$config_file")"
    
    # Read existing values or use defaults
    local existing_display_mgr="sddm"
    local existing_display_server="wayland"
    local existing_session="$desktop_env"
    local existing_dark="true"
    local existing_audio="pipewire"
    
    if [ -f "$config_file" ]; then
        existing_display_mgr=$(grep -o 'manager = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "sddm")
        existing_display_server=$(grep -o 'server = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "wayland")
        existing_session=$(grep -o 'session = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "$desktop_env")
        existing_dark=$(grep -o 'dark = [^;]*' "$config_file" 2>/dev/null | grep -o '[^=]*$' | tr -d ' ' || echo "true")
        existing_audio=$(grep -o 'audio = "[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "pipewire")
    fi
    
    # Set display manager based on desktop environment
    case "$desktop_env" in
        "plasma") existing_display_mgr="sddm" ;;
        "gnome") existing_display_mgr="gdm" ;;
        "xfce") existing_display_mgr="lightdm" ;;
    esac
    
    cat > "$config_file" <<EOF
{
  desktop = {
    enable = true;
    environment = "$desktop_env";
    display = {
      manager = "$existing_display_mgr";
      server = "$existing_display_server";
      session = "$existing_session";
    };
    theme = {
      dark = $existing_dark;
    };
    audio = "$existing_audio";
  };
}
EOF
}

setup_custom() {
    log_section "Custom Install"

    # Parse arguments: system_type feature1 feature2 ...
    local system_type="$1"
    shift
    local features=("$@")

    # Backup
    backup_config || return 1

    # Update systemType
    update_system_type "$system_type" || return 1

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

    # Update desktop-config.nix if Desktop Environment selected
    if [[ -n "$desktop_env" ]]; then
        update_desktop_config "$desktop_env" || return 1
    fi

    # Update packages-config.nix
    if [[ ${#package_features[@]} -gt 0 ]]; then
        local package_modules_string="${package_features[*]}"
        update_packages_config "$package_modules_string" || return 1
    else
        update_packages_config "" || return 1
    fi

    # Check for Docker features and handle user setup
    detect_and_setup_docker_users "${package_features[@]}" || return 1

    # Export system type for deployment
    export SYSTEM_TYPE="$system_type"
    deploy_config

    log_success "Custom install complete"
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
        local backup_root="/var/backup/nixos/directories"
        local backup_dir="$backup_root/configs.$(date +%Y%m%d_%H%M%S)"
        # Create directory if it doesn't exist (ActivationScript should have created it)
        if [[ ! -d "$backup_root" ]]; then
            mkdir -p "$backup_root"
            chmod 700 "$backup_root" 2>/dev/null || sudo chmod 700 "$backup_root" 2>/dev/null || true
            chown root:root "$backup_root" 2>/dev/null || sudo chown root:root "$backup_root" 2>/dev/null || true
        else
            mkdir -p "$backup_root"  # Ensure it exists
        fi
        # Create backup directory and set permissions (700 for dirs, 600 for files)
        if cp -r "$(dirname "$SYSTEM_CONFIG_FILE")/configs" "$backup_dir" 2>/dev/null || sudo cp -r "$(dirname "$SYSTEM_CONFIG_FILE")/configs" "$backup_dir" 2>/dev/null; then
            chmod -R 700 "$backup_dir" 2>/dev/null || sudo chmod -R 700 "$backup_dir" 2>/dev/null || true
            find "$backup_dir" -type f -exec chmod 600 {} \; 2>/dev/null || sudo find "$backup_dir" -type f -exec chmod 600 {} \; 2>/dev/null || true
            chown -R root:root "$backup_dir" 2>/dev/null || sudo chown -R root:root "$backup_dir" 2>/dev/null || true
            # Cleanup old backups (keep last 5)
            ls -dt "$backup_root"/configs.* 2>/dev/null | tail -n +6 | xargs -r rm -rf 2>/dev/null || sudo xargs -r rm -rf 2>/dev/null || true
            log_info "Backup created: $backup_dir"
        fi
    fi
    return 0
}

# Detect Docker features and setup users accordingly
detect_and_setup_docker_users() {
    local features=("$@")
    local docker_feature=""
    local docker_mode=""
    
    # Check for Docker features
    for feature in "${features[@]}"; do
        if [[ "$feature" == "docker" ]]; then
            docker_feature="docker"
            # Docker mode wird automatisch in getDockerMode entschieden (rootless default, root bei Swarm/AI-Workspace)
            # Für User Setup: rootless ist Standard (kein extra user nötig)
            docker_mode="docker-rootless"  # Default für User Setup
            break
        fi
    done
    
    # If no Docker feature, skip user setup
    if [[ -z "$docker_feature" ]]; then
        return 0
    fi
    
    # Check if Swarm is configured (check for homelab-manager feature or homelab block)
    local swarm_role="none"
    local features_config="$(dirname "$SYSTEM_CONFIG_FILE")/configs/features-config.nix"
    if [[ -f "$features_config" ]] && grep -q "homelab-manager.*=.*true" "$features_config" 2>/dev/null; then
        # Check if homelab block exists with swarm
        if [[ -f "$SYSTEM_CONFIG_FILE" ]] && grep -q "homelab" "$SYSTEM_CONFIG_FILE" 2>/dev/null; then
            if grep -q 'role = "manager"' "$SYSTEM_CONFIG_FILE" 2>/dev/null; then
                swarm_role="manager"
            elif grep -q 'role = "worker"' "$SYSTEM_CONFIG_FILE" 2>/dev/null; then
                swarm_role="worker"
            fi
        fi
    fi
    
    # Setup users based on Docker mode and Swarm
    if [[ "$swarm_role" != "none" ]]; then
        # Swarm requires Extra User
        setup_docker_users "extra" "$docker_mode" || return 1
    else
        # Single-Server: Ask for user setup
        local use_extra_user=$(get_docker_user_setup "$docker_mode") || return 1
        setup_docker_users "$use_extra_user" "$docker_mode" || return 1
    fi
    
    return 0
}

# Get Docker user setup preference
get_docker_user_setup() {
    local docker_mode="$1"  # "docker" (wird automatisch rootless oder root)
    local default_response="n"  # Rootless Docker (Standard) → Main User (default)
    
    # Check if Swarm is active (dann braucht man root, aber das wird automatisch gemacht)
    # Für User Setup: rootless ist Standard
    
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

# Setup Docker users in system-config.nix
setup_docker_users() {
    local user_setup_mode="$1"  # "extra" or "main"
    local docker_mode="$2"  # "docker" (wird automatisch rootless oder root entschieden)
    
    local main_user="$(logname)"
    local virt_user=""
    local users_block=""
    
    if [[ "$user_setup_mode" == "extra" ]]; then
        # Ask for virt_user
        read -ep $'\033[0;34m[?]\033[0m Enter virtualization username(docker) [docker]: ' virt_user
        virt_user="${virt_user:-docker}"
        
        # Build users block with both users
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
        # Use main user as admin (homelab-manager accepts admin as fallback)
        users_block="    \"$main_user\" = {
      role = \"admin\";
      defaultShell = \"zsh\";
      autoLogin = false;
    };"
    fi
    
    # Update system-config.nix with users block
    update_users_config "$users_block" || return 1
    
    return 0
}

# Helper to update users block in system-config.nix
update_users_config() {
    local users_block="$1"
    local temp_file=$(mktemp)
    
    # Read existing system-config.nix
    if [ -f "$SYSTEM_CONFIG_FILE" ]; then
        cp "$SYSTEM_CONFIG_FILE" "$temp_file"
    else
        # Create minimal system-config.nix if it doesn't exist
        cat > "$temp_file" <<EOF
{
  systemType = "server";
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

# Export functions
export -f setup_custom
export -f update_packages_config
export -f update_system_type
export -f update_desktop_config
export -f backup_config
export -f detect_and_setup_docker_users
export -f get_docker_user_setup
export -f setup_docker_users
export -f update_users_config

# Check script execution and run
check_script_execution "SYSTEM_CONFIG_FILE" "setup_custom $*"

