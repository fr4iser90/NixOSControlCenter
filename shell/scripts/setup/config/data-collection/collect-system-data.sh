#!/usr/bin/env bash

# =============================================================
# Data Collection - System Setup
# =============================================================
# Collects system information and writes configs to v1 modular structure
# Uses config-writer.sh for all config file creation
# =============================================================

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
    [[ -d "$(dirname "$SYSTEM_CONFIG_FILE")/systemConfig" ]] && {
        log_info "Backing up existing configs directory..."
        BACKUP_ROOT="/var/backup/nixos/directories"
        BACKUP_DIR="$BACKUP_ROOT/systemConfig.$(date +%Y%m%d_%H%M%S)"
        if [ ! -d "$BACKUP_ROOT" ]; then
            mkdir -p "$BACKUP_ROOT"
            chmod 700 "$BACKUP_ROOT" 2>/dev/null || sudo chmod 700 "$BACKUP_ROOT" 2>/dev/null || true
            chown root:root "$BACKUP_ROOT" 2>/dev/null || sudo chown root:root "$BACKUP_ROOT" 2>/dev/null || true
        else
            mkdir -p "$BACKUP_ROOT"
        fi
        if cp -r "$(dirname "$SYSTEM_CONFIG_FILE")/systemConfig" "$BACKUP_DIR" 2>/dev/null || sudo cp -r "$(dirname "$SYSTEM_CONFIG_FILE")/systemConfig" "$BACKUP_DIR" 2>/dev/null; then
            chmod -R 700 "$BACKUP_DIR" 2>/dev/null || sudo chmod -R 700 "$BACKUP_DIR" 2>/dev/null || true
            find "$BACKUP_DIR" -type f -exec chmod 600 {} \; 2>/dev/null || sudo find "$BACKUP_DIR" -type f -exec chmod 600 {} \; 2>/dev/null || true
            chown -R root:root "$BACKUP_DIR" 2>/dev/null || sudo chown -R root:root "$BACKUP_DIR" 2>/dev/null || true
            ls -dt "$BACKUP_ROOT"/systemConfig.* 2>/dev/null | tail -n +6 | xargs -r rm -rf 2>/dev/null || sudo xargs -r rm -rf 2>/dev/null || true
            log_info "Backup created: $BACKUP_DIR"
        fi
    }

    # Clean old-style config files (from previous versions)
    clean_old_configs 2>/dev/null || true

    # Determine system type for this setup
    local sys_type="${SYSTEM_TYPE:-desktop}"
    local host_name="${HOSTNAME:-$(hostname)}"
    local timezone="${SYSTEM_TIMEZONE:-Europe/Berlin}"
    local bootloader="${BOOT_TYPE:-systemd-boot}"
    local allow_unfree="${ALLOW_UNFREE:-false}"
    
    # Get users from collection
    local users_block="${ALL_USERS:-}"
    if [[ -z "$users_block" ]]; then
        local current_user
        current_user=$(whoami 2>/dev/null || echo "user")
        local current_shell
        current_shell=$(basename "$(getent passwd "$current_user" 2>/dev/null | cut -d: -f7)" 2>/dev/null || echo "bash")
        users_block="    \"$current_user\" = {
      role = \"admin\";
      defaultShell = \"$current_shell\";
      autoLogin = false;
    };"
    fi

    # --- Write all v1 modular configs ---
    
    # 1. Minimal system-config.nix (entry point)
    write_system_config "$sys_type" "$host_name" "$timezone" "$users_block" "$bootloader"
    
    # 2. System manager config (v1 modular location)
    write_system_manager_config "$sys_type" "$allow_unfree" "stable" "$bootloader"
    
    # 3. Network config
    write_network_config "$host_name"
    
    # 4. Localization config
    local locale="${SYSTEM_LOCALE:-en_US.UTF-8}"
    local keyboard_layout="${SYSTEM_KEYBOARD_LAYOUT:-us}"
    local keyboard_options="${SYSTEM_KEYBOARD_OPTIONS:-}"
    write_localization_config "$locale" "$keyboard_layout" "$keyboard_options" "$timezone"
    
    # 5. Hardware config
    local cpu="${CPU_VENDOR:-none}"
    local gpu="${GPU_CONFIG:-none}"
    local memory_gb="${MEMORY_GB:-}"
    write_hardware_config "$cpu" "$gpu" "$memory_gb"
    
    # 6. Desktop config (if desktop mode)
    if [[ "$sys_type" == "desktop" ]]; then
        local desktop_env="${DESKTOP:-plasma}"
        local display_mgr="${DISPLAY_MGR:-sddm}"
        local display_server="${DISPLAY_SERVER:-wayland}"
        local session="${SESSION:-plasma}"
        local dark_mode="${DARK_MODE:-true}"
        local audio="${AUDIO:-pipewire}"
        write_desktop_config "$desktop_env" "$display_mgr" "$display_server" "$session" "$dark_mode" "$audio"
        write_audio_config "$audio"
    else
        write_desktop_disabled
    fi
    
    # 7. Packages config
    local package_modules="${PACKAGE_MODULES:-}"
    if [[ -n "$package_modules" ]]; then
        # Convert space-separated to individual args
        read -ra mod_array <<< "$package_modules"
        write_packages_config "${mod_array[@]}"
    else
        write_packages_config
    fi
    
    # 8. Hosting config (email/domain if provided)
    local host_email="${HOST_EMAIL:-}"
    local host_domain="${HOST_DOMAIN:-}"
    if [[ -n "$host_email" || -n "$host_domain" ]]; then
        write_hosting_config "$host_email" "$host_domain"
    fi
    
    # 9. Override config (SSH)
    local override_ssh="${OVERRIDE_SSH:-null}"
    write_overrides_config "$override_ssh"
    
    # 10. Logging config
    local build_log_level="${BUILD_LOG_LEVEL:-minimal}"
    write_logging_config "$build_log_level"

    log_success "System configuration files created (v1 modular)"
}

restore_backup() {
    # Restore system-config.nix backup (from /var/backup/nixos/systemConfig/)
    local backup_root="/var/backup/nixos/systemConfig"
    local latest_backup
    latest_backup=$(ls -t "$backup_root"/system-config.nix.backup.* 2>/dev/null | head -1)
    if [[ -n "$latest_backup" && -f "$latest_backup" ]]; then
        cp "$latest_backup" "$SYSTEM_CONFIG_FILE"
        log_info "Restored backup configuration from $latest_backup"
    fi
    
    # Restore configs directory backup (from /var/backup/nixos/directories/)
    backup_root="/var/backup/nixos/directories"
    local latest_dir_backup
    latest_dir_backup=$(ls -td "$backup_root"/systemConfig.* 2>/dev/null | head -1)
    if [[ -n "$latest_dir_backup" && -d "$latest_dir_backup" ]]; then
        rm -rf "$(dirname "$SYSTEM_CONFIG_FILE")/systemConfig"
        cp -r "$latest_dir_backup" "$(dirname "$SYSTEM_CONFIG_FILE")/systemConfig"
        log_info "Restored backup configs directory from $latest_dir_backup"
    fi
}

# Export functions
export -f collect_system_data
export -f restore_backup

# Check script execution
check_script_execution "SYSTEM_CONFIG_FILE" "collect_system_data"
