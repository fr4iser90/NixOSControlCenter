#!/usr/bin/env bash

collect_system_data() {
    log_section "Collecting System Information"
    
    local temp_config="${INSTALL_TMP}/../system-config.nix.tmp"

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

    # Backup existing config
    [[ -f "$SYSTEM_CONFIG_FILE" ]] && backup_file "$SYSTEM_CONFIG_FILE"


    # Create temp config from template
    cp "$SYSTEM_CONFIG_TEMPLATE" "$temp_config" || {
        log_error "Failed to create temp config"
        return 1
    }

    init_system_type
    init_profile_modules
    init_primary_user
    init_users_block
    init_desktop_env
    init_hardware_config
    init_nix_config
    init_security_settings
    init_localization
    init_hosting_config
    init_profile_overrides

    # Activate new configuration
    if [[ -s "$temp_config" ]]; then
        ensure_dir "$(dirname "$SYSTEM_CONFIG_FILE")"
        mv "$temp_config" "$SYSTEM_CONFIG_FILE" || {
            log_error "Failed to move config file"
            return 1
        }
        log_success "System configuration updated at $SYSTEM_CONFIG_FILE"
    else
        log_error "Generated config is empty!"
        restore_backup
        return 1
    fi
}

# Helper functions for each section
init_system_type() {
    log_debug "Updating system type..."
    sed -i \
        -e "s|@SYSTEM_TYPE@|desktop|" \
        -e "s|@HOSTNAME@|$(hostname)|" \
        -e "s|@BOOTLOADER@|$BOOT_TYPE|" \
        "$temp_config"
}

init_profile_modules() {
    log_debug "Updating profile modules..."
    sed -i \
        -e "s|@GAMING_STREAMING@|false|" \
        -e "s|@GAMING_EMULATION@|false|" \
        -e "s|@DEV_GAME@|false|" \
        -e "s|@DEV_WEB@|false|" \
        -e "s|@SERVER_DOCKER@|false|" \
        -e "s|@SERVER_WEB@|false|" \
        "$temp_config"
}

init_primary_user() {
    log_debug "Updating primary user..."
    local current_user=$(whoami)
    local current_shell=$(basename $(getent passwd $current_user | cut -d: -f7))
    local user_role="admin"
    
    sed -i \
        -e "s|@PRIMARY_USER@|$current_user|" \
        -e "s|@PRIMARY_ROLE@|$user_role|" \
        -e "s|@PRIMARY_SHELL@|$current_shell|" \
        -e "s|@PRIMARY_AUTOLOGIN@|false|" \
        -e 's|@PRIMARY_GROUPS@|"wheel" "networkmanager"|' \
        -e 's|@PRIMARY_PASS@|""|' \
        -e 's|@PRIMARY_SSH_KEYS@||' \
        -e 's|@PRIMARY_TTY@||' \
        "$temp_config"
}

init_users_block() {
    log_debug "Updating users block..."
    echo "$ALL_USERS" > "${INSTALL_TMP}/users.tmp"
    sed -i -e '/^[[:space:]]*@USERS@/r '"${INSTALL_TMP}/users.tmp" \
           -e '/^[[:space:]]*@USERS@/d' "$temp_config"
    rm "${INSTALL_TMP}/users.tmp"
}

init_desktop_env() {
    log_debug "Updating desktop environment..."
    sed -i \
        -e "s|@ENABLE_DESKTOP@|true|" \
        -e "s|@DESKTOP@|plasma|" \
        -e "s|@DISPLAY_MGR@|sddm|" \
        -e "s|@DISPLAY_SERVER@|wayland|" \
        -e "s|@SESSION@|plasma|" \
        -e "s|@DARK_MODE@|true|" \
        "$temp_config"
}

init_hardware_config() {
    log_debug "Updating hardware configuration..."
    sed -i \
        -e "s|@CPU@|$CPU_VENDOR|" \
        -e "s|@GPU@|$GPU_CONFIG|" \
        "$temp_config"
}

init_nix_config() {
    log_debug "Updating Nix configuration..."
    sed -i \
        -e "s|@ALLOW_UNFREE@|true|" \
        -e "s|@BUILD_LOG_LEVEL@|minimal|" \
        -e "s|@ENTRY_MANAGEMENT@|false|" \
        -e "s|@PREBUILD_CHECKS@|false|" \
        -e "s|@SSH_CLIENT_MANAGER@|false|" \
        -e "s|@SSH_SERVER_MANAGER@|false|" \
        -e "s|@FLAKE_UPDATER@|false|" \
        "$temp_config"
}

init_security_settings() {
    log_debug "Updating security settings..."
    sed -i \
        -e "s|@SUDO_REQUIRE_PASS@|false|" \
        -e "s|@SUDO_TIMEOUT@|15|" \
        -e "s|@ENABLE_FIREWALL@|false|" \
        "$temp_config"
}

init_localization() {
    log_debug "Updating localization..."
    sed -i \
        -e "s|@TIMEZONE@|$SYSTEM_TIMEZONE|" \
        -e "s|@LOCALE@|$SYSTEM_LOCALE|" \
        -e "s|@KEYBOARD_LAYOUT@|$SYSTEM_KEYBOARD_LAYOUT|" \
        -e "s|@KEYBOARD_OPTIONS@|$SYSTEM_KEYBOARD_OPTIONS|" \
        "$temp_config"
}

init_hosting_config() {
    log_debug "Updating hosting configuration..."
    sed -i \
        -e "s|@DOMAIN@|${HOST_DOMAIN:-example.com}|" \
        -e "s|@EMAIL@|${HOST_EMAIL:-admin@example.com}|" \
        -e "s|@CERT_EMAIL@|${CERT_EMAIL:-admin@example.com}|" \
        -e "s|@VIRT_USER@|${VIRT_USER:-docker}|" \
        "$temp_config"
}

init_profile_overrides() {
    log_debug "Updating profile overrides..."
    sed -i \
        -e "s|@OVERRIDE_SSH@|null|" \
        -e "s|@OVERRIDE_STEAM@|true|" \
        "$temp_config"
}

restore_backup() {
    if [[ -f "${SYSTEM_CONFIG_FILE}.backup" ]]; then
        mv "${SYSTEM_CONFIG_FILE}.backup" "$SYSTEM_CONFIG_FILE"
        log_info "Restored backup configuration"
    fi
}

# Export functions
export -f collect_system_data
export -f restore_backup

# Check script execution
check_script_execution "SYSTEM_CONFIG_FILE" "collect_system_data"