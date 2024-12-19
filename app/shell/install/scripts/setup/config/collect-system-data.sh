#!/usr/bin/env bash

log_section "Collecting System Information"

collect_system_data() {
    local temp_config="${INSTALL_TMP}/system-config.nix.tmp"

    # Hardware Checks
    log_info "Checking Hardware..."
    source "${CHECKS_DIR}/hardware/cpu.sh"
    source "${CHECKS_DIR}/hardware/gpu.sh"

    # System Checks
    log_info "Checking System Configuration..."
    source "${CHECKS_DIR}/system/locale.sh"
    source "${CHECKS_DIR}/system/users.sh"
    source "${CHECKS_DIR}/system/bootloader.sh"

    # Backup erstellen wenn Datei existiert
    if [ -f "$SYSTEM_CONFIG_FILE" ]; then
        backup_file "$SYSTEM_CONFIG_FILE"
    fi

    # Template kopieren und anpassen
    cp "$SYSTEM_CONFIG_TEMPLATE" "$temp_config"

    # System Type & Profile
    sed -i \
        -e "s|@SYSTEM_TYPE@|desktop|" \
        -e "s|@HOSTNAME@|$(hostname)|" \
        -e "s|@BOOTLOADER@|$BOOT_TYPE|" \
        "$temp_config"

    # Profile Modules (Default-Werte)
    sed -i \
        -e "s|@GAMING_STREAMING@|false|" \
        -e "s|@GAMING_EMULATION@|false|" \
        -e "s|@DEV_GAME@|false|" \
        -e "s|@DEV_WEB@|false|" \
        -e "s|@SERVER_DOCKER@|false|" \
        -e "s|@SERVER_WEB@|false|" \
        "$temp_config"

    # Primary User
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



    # Ersetze @USERS@ direkt mit dem User-Block
    echo "$ALL_USERS" > "${INSTALL_TMP}/users.tmp"
    sed -i -e '/^[[:space:]]*@USERS@/r '"${INSTALL_TMP}/users.tmp" \
           -e '/^[[:space:]]*@USERS@/d' "$temp_config"
    rm "${INSTALL_TMP}/users.tmp"

    # Desktop Environment
    sed -i \
        -e "s|@DESKTOP@|plasma|" \
        -e "s|@DISPLAY_MGR@|sddm|" \
        -e "s|@DISPLAY_SERVER@|wayland|" \
        -e "s|@SESSION@|plasma|" \
        -e "s|@DARK_MODE@|true|" \
        "$temp_config"

    # Hardware Configuration
    sed -i \
        -e "s|@CPU@|$CPU_VENDOR|" \
        -e "s|@GPU@|$GPU_CONFIG|" \
        -e "s|@AUDIO@|pipewire|" \
        "$temp_config"

    # Nix Configuration & Features
    sed -i \
        -e "s|@ALLOW_UNFREE@|true|" \
        -e "s|@BUILD_LOG_LEVEL@|minimal|" \
        -e "s|@ENTRY_MANAGEMENT@|true|" \
        -e "s|@PREFLIGHT_CHECKS@|true|" \
        -e "s|@SSH_MANAGER@|true|" \
        -e "s|@FLAKE_UPDATER@|true|" \
        "$temp_config"

    # Security Settings
    sed -i \
        -e "s|@SUDO_REQUIRE_PASS@|false|" \
        -e "s|@SUDO_TIMEOUT@|15|" \
        -e "s|@ENABLE_FIREWALL@|false|" \
        "$temp_config"

    # Localization
    sed -i \
        -e "s|@TIMEZONE@|$SYSTEM_TIMEZONE|" \
        -e "s|@LOCALE@|$SYSTEM_LOCALE|" \
        -e "s|@KEYBOARD_LAYOUT@|$SYSTEM_KEYBOARD_LAYOUT|" \
        -e "s|@KEYBOARD_OPTIONS@|$SYSTEM_KEYBOARD_OPTIONS|" \
        "$temp_config"

    # Profile Overrides
    sed -i \
        -e "s|@OVERRIDE_SSH@|null|" \
        -e "s|@OVERRIDE_STEAM@|true|" \
        "$temp_config"

    # Aktiviere neue Konfiguration
    if [ -s "$temp_config" ]; then
        ensure_dir "$(dirname "$SYSTEM_CONFIG_FILE")"
        mv "$temp_config" "$SYSTEM_CONFIG_FILE"
        log_success "System configuration updated at $SYSTEM_CONFIG_FILE"
    else
        log_error "Generated config is empty!"
        if [ -f "${SYSTEM_CONFIG_FILE}.backup" ]; then
            mv "${SYSTEM_CONFIG_FILE}.backup" "$SYSTEM_CONFIG_FILE"
            log_info "Restored backup configuration"
        fi
        return 1
    fi
}

# Ausführen
collect_system_data