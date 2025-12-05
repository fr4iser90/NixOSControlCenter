#!/usr/bin/env bash

collect_system_data() {
    log_section "Collecting System Information"
    
    # Hardware checks
    log_info "Checking Hardware..."
    check_cpu_info || return 1
    check_gpu_info || return 1

    # System checks
    log_info "Checking System Configuration..."
    check_locale || return 1
    check_users || return 1
    check_bootloader || return 1
    check_hosting || return 1

    # Backup existing configs
    [[ -f "$SYSTEM_CONFIG_FILE" ]] && backup_file "$SYSTEM_CONFIG_FILE"
    [[ -d "$(dirname "$SYSTEM_CONFIG_FILE")/configs" ]] && {
        log_info "Backing up existing configs directory..."
        cp -r "$(dirname "$SYSTEM_CONFIG_FILE")/configs" "$(dirname "$SYSTEM_CONFIG_FILE")/configs.backup.$(date +%s)" 2>/dev/null || true
    }

    # Ensure configs directory exists
    ensure_dir "$(dirname "$SYSTEM_CONFIG_FILE")/configs"

    # Create all config files
    init_system_config
    init_packages_config
    init_desktop_config
    init_localization_config
    init_hardware_config
    init_features_config
    init_logging_config
    init_hosting_config
    init_overrides_config

    log_success "System configuration files created"
}

# Helper function to write Nix config file
write_nix_config() {
    local config_file="$1"
    local content="$2"
    
    ensure_dir "$(dirname "$config_file")"
    cat > "$config_file" <<EOF
$content
EOF
    log_debug "Created config file: $config_file"
}

# Create minimal system-config.nix
init_system_config() {
    log_debug "Creating system-config.nix..."
    local current_user=$(whoami)
    local current_shell=$(basename $(getent passwd $current_user | cut -d: -f7) 2>/dev/null || echo "bash")
    local user_role="admin"
    
    # Build users block
    local users_block=""
    if [[ -n "${ALL_USERS:-}" ]]; then
        users_block="$ALL_USERS"
    else
        users_block="    \"$current_user\" = {
      role = \"$user_role\";
      defaultShell = \"$current_shell\";
      autoLogin = false;
    };"
    fi
    
    write_nix_config "$SYSTEM_CONFIG_FILE" "{
  # System-Identität
  systemType = \"${SYSTEM_TYPE:-desktop}\";
  hostName = \"$(hostname)\";
  
  # System-Version
  system = {
    channel = \"stable\";
    bootloader = \"${BOOT_TYPE:-systemd-boot}\";
  };
  
  # Nix-Config
  allowUnfree = true;
  
  # User-Management
  users = {
$users_block
  };
  
  # TimeZone
  timeZone = \"${SYSTEM_TIMEZONE:-Europe/Berlin}\";
}
"
}

# Create packages-config.nix
init_packages_config() {
    log_debug "Creating packages-config.nix..."
    local package_modules="${PACKAGE_MODULES:-}"
    local preset="${PRESET:-null}"
    local additional_modules="${ADDITIONAL_PACKAGE_MODULES:-}"
    
    local content="{"
    if [[ -n "$package_modules" ]]; then
        content+="
  # Package-Modules direkt
  packageModules = [ $package_modules ];"
    elif [[ "$preset" != "null" ]]; then
        content+="
  # Preset verwenden
  preset = \"$preset\";"
        if [[ -n "$additional_modules" ]]; then
            content+="
  additionalPackageModules = [ $additional_modules ];"
        fi
    else
        content+="
  # Package-Modules (leer - wird später konfiguriert)
  packageModules = [];"
    fi
    content+="
}
"
    
    write_nix_config "$(dirname "$SYSTEM_CONFIG_FILE")/configs/packages-config.nix" "$content"
}

# Create desktop-config.nix
init_desktop_config() {
    log_debug "Creating desktop-config.nix..."
    local enable_desktop="${ENABLE_DESKTOP:-true}"
    local desktop="${DESKTOP:-plasma}"
    local display_mgr="${DISPLAY_MGR:-sddm}"
    local display_server="${DISPLAY_SERVER:-wayland}"
    local session="${SESSION:-plasma}"
    local dark_mode="${DARK_MODE:-true}"
    local audio="${AUDIO:-pipewire}"
    
    write_nix_config "$(dirname "$SYSTEM_CONFIG_FILE")/configs/desktop-config.nix" "{
  # Desktop-Environment
  desktop = {
    enable = $enable_desktop;
    environment = \"$desktop\";
    display = {
      manager = \"$display_mgr\";
      server = \"$display_server\";
      session = \"$session\";
    };
    theme = {
      dark = $dark_mode;
    };
    audio = \"$audio\";
  };
}
"
}

# Create localization-config.nix
init_localization_config() {
    log_debug "Creating localization-config.nix..."
    local locale="${SYSTEM_LOCALE:-en_US.UTF-8}"
    local keyboard_layout="${SYSTEM_KEYBOARD_LAYOUT:-us}"
    local keyboard_options="${SYSTEM_KEYBOARD_OPTIONS:-}"
    
    local content="{"
    content+="
  # Lokalisierung
  locales = [ \"$locale\" ];
  keyboardLayout = \"$keyboard_layout\";"
    if [[ -n "$keyboard_options" ]]; then
        content+="
  keyboardOptions = \"$keyboard_options\";"
    fi
    content+="
}
"
    
    write_nix_config "$(dirname "$SYSTEM_CONFIG_FILE")/configs/localization-config.nix" "$content"
}

# Create hardware-config.nix
init_hardware_config() {
    log_debug "Creating hardware-config.nix..."
    local cpu="${CPU_VENDOR:-none}"
    local gpu="${GPU_CONFIG:-none}"
    local memory_gb="${MEMORY_GB:-}"
    
    local content="{"
    content+="
  hardware = {
    cpu = \"$cpu\";
    gpu = \"$gpu\";"
    if [[ -n "$memory_gb" ]]; then
        content+="
    ram = {
      sizeGB = $memory_gb;
    };"
    fi
    content+="
  };
}
"
    
    write_nix_config "$(dirname "$SYSTEM_CONFIG_FILE")/configs/hardware-config.nix" "$content"
}

# Create features-config.nix
init_features_config() {
    log_debug "Creating features-config.nix..."
    local system_logger="${SYSTEM_LOGGER:-true}"
    local system_checks="${SYSTEM_CHECKS:-true}"
    local system_updater="${SYSTEM_UPDATER:-true}"
    local ssh_client="${SSH_CLIENT_MANAGER:-false}"
    local ssh_server="${SSH_SERVER_MANAGER:-false}"
    local bootentry="${BOOTENTRY_MANAGER:-false}"
    local homelab="${HOMELAB_MANAGER:-false}"
    local vm="${VM_MANAGER:-false}"
    local ai="${AI_WORKSPACE:-false}"
    
    write_nix_config "$(dirname "$SYSTEM_CONFIG_FILE")/configs/features-config.nix" "{
  features = {
    system-logger = $system_logger;
    system-checks = $system_checks;
    system-updater = $system_updater;
    ssh-client-manager = $ssh_client;
    ssh-server-manager = $ssh_server;
    bootentry-manager = $bootentry;
    homelab-manager = $homelab;
    vm-manager = $vm;
    ai-workspace = $ai;
  };
}
"
}

# Create logging-config.nix
init_logging_config() {
    log_debug "Creating logging-config.nix..."
    local build_log_level="${BUILD_LOG_LEVEL:-minimal}"
    
    write_nix_config "$(dirname "$SYSTEM_CONFIG_FILE")/configs/logging-config.nix" "{
  # Build-Logging
  buildLogLevel = \"$build_log_level\";
}
"
}

# Create hosting-config.nix
init_hosting_config() {
    log_debug "Creating hosting-config.nix..."
    local domain="${HOST_DOMAIN:-}"
    local email="${HOST_EMAIL:-}"
    
    if [[ -z "$domain" && -z "$email" ]]; then
        # Skip if no hosting info
        return 0
    fi
    
    local content="{"
    if [[ -n "$email" ]]; then
        content+="
  email = \"$email\";"
    fi
    if [[ -n "$domain" ]]; then
        content+="
  domain = \"$domain\";"
    fi
    content+="
}
"
    
    write_nix_config "$(dirname "$SYSTEM_CONFIG_FILE")/configs/hosting-config.nix" "$content"
}

# Create overrides-config.nix
init_overrides_config() {
    log_debug "Creating overrides-config.nix..."
    local override_ssh="${OVERRIDE_SSH:-null}"
    
    local content="{"
    content+="
  overrides = {"
    if [[ "$override_ssh" != "null" ]]; then
        content+="
    enableSSH = $override_ssh;"
    else
        content+="
    enableSSH = null;"
    fi
    content+="
  };
}
"
    
    write_nix_config "$(dirname "$SYSTEM_CONFIG_FILE")/configs/overrides-config.nix" "$content"
}

restore_backup() {
    if [[ -f "${SYSTEM_CONFIG_FILE}.backup" ]]; then
        mv "${SYSTEM_CONFIG_FILE}.backup" "$SYSTEM_CONFIG_FILE"
        log_info "Restored backup configuration"
    fi
    if [[ -d "$(dirname "$SYSTEM_CONFIG_FILE")/configs.backup."* ]]; then
        local backup_dir=$(ls -td "$(dirname "$SYSTEM_CONFIG_FILE")/configs.backup."* 2>/dev/null | head -1)
        if [[ -n "$backup_dir" ]]; then
            rm -rf "$(dirname "$SYSTEM_CONFIG_FILE")/configs"
            mv "$backup_dir" "$(dirname "$SYSTEM_CONFIG_FILE")/configs"
            log_info "Restored backup configs directory"
        fi
    fi
}

# Export functions
export -f collect_system_data
export -f restore_backup

# Check script execution
check_script_execution "SYSTEM_CONFIG_FILE" "collect_system_data"
