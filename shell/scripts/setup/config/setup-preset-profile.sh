#!/usr/bin/env bash

# =============================================================
# Preset Profile Loader - v1 Modular Config System
# =============================================================
# Reads preset profile files and converts them to v1 modular structure
# Uses config-writer.sh for all config file creation
# =============================================================

# Parse a value from a Nix config file
# Usage: parse_nix_value "file" "key"
parse_nix_value() {
    local file="$1"
    local key="$2"
    local value
    
    value=$(grep -A1 "^  ${key} = " "$file" 2>/dev/null | head -2 | tail -1 | sed 's/;//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    echo "$value"
}

# Parse package modules from a Nix config file
# Returns: space-separated quoted list like: "gaming" "streaming" "emulation"
parse_package_modules() {
    local file="$1"
    local in_modules=0
    local modules=""
    
    while IFS= read -r line; do
        if echo "$line" | grep -q "^  packageModules = \["; then
            in_modules=1
            continue
        fi
        if [[ $in_modules -eq 1 ]]; then
            if echo "$line" | grep -q "\]"; then
                break
            fi
            local mod
            mod=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[$,]//g' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            if [[ -n "$mod" && "$mod" != "packageModules" ]]; then
                if [[ -n "$modules" ]]; then
                    modules="$modules $mod"
                else
                    modules="$mod"
                fi
            fi
        fi
    done < "$file"
    
    echo "$modules"
}

# Parse users block from a Nix config file
# Returns: users block content
parse_users_block() {
    local file="$1"
    local in_users=0
    local brace_count=0
    local users_block=""
    
    while IFS= read -r line; do
        if echo "$line" | grep -q "^  users = {"; then
            in_users=1
            continue
        fi
        if [[ $in_users -eq 1 ]]; then
            brace_count=$((brace_count + $(echo "$line" | tr -cd '{' | wc -c)))
            brace_count=$((brace_count - $(echo "$line" | tr -cd '}' | wc -c)))
            users_block+="$line"$'\n'
            if [[ $brace_count -le 0 ]]; then
                break
            fi
        fi
    done < "$file"
    
    echo "$users_block"
}

# Parse desktop config from a Nix config file
# Returns: desktop environment name or empty
parse_desktop_env() {
    local file="$1"
    local env
    env=$(grep -A5 "^  desktop = {" "$file" 2>/dev/null | grep "environment = " | head -1 | sed 's/.*="//' | sed 's/".*//')
    echo "$env"
}

# Parse hardware info from a Nix config file
parse_hardware_cpu() {
    local file="$1"
    parse_nix_value "$file" "cpu"
}

parse_hardware_gpu() {
    local file="$1"
    parse_nix_value "$file" "gpu"
}

parse_hardware_ram() {
    local file="$1"
    local ram
    ram=$(grep -A2 "ram = {" "$file" 2>/dev/null | grep "sizeGB = " | head -1 | sed 's/.*sizeGB = //' | sed 's/;//' | sed 's/[[:space:]]//g')
    echo "$ram"
}

# =============================================================
# Main preset loader function
# =============================================================
setup_predefined_profile() {
    local profile_file="$1"
    
    log_section "Setting up Presdefined Profile"
    log_info "Loading profile from: $profile_file"
    
    if [[ ! -f "$profile_file" ]]; then
        log_error "Profile file not found: $profile_file"
        return 1
    fi
    
    # Backup existing configs
    if [[ -f "$SYSTEM_CONFIG_FILE" ]]; then
        backup_file "$SYSTEM_CONFIG_FILE" || {
            log_error "Failed to create backup"
            return 1
        }
    fi
    if [[ -d "$(dirname "$SYSTEM_CONFIG_FILE")/systemConfig" ]]; then
        clean_old_configs 2>/dev/null || true
    fi
    
    # Parse profile values
    local system_type
    system_type=$(parse_nix_value "$profile_file" "systemType" | tr -d '"')
    system_type="${system_type:-desktop}"
    
    local host_name
    host_name=$(parse_nix_value "$profile_file" "hostName" | tr -d '"')
    if [[ -z "$host_name" || "$host_name" == "null" ]]; then
        host_name="$(hostname)"
    fi
    
    local timezone
    timezone=$(parse_nix_value "$profile_file" "timeZone" | tr -d '"')
    timezone="${timezone:-Europe/Berlin}"
    
    local allow_unfree
    allow_unfree=$(parse_nix_value "$profile_file" "allowUnfree" | tr -d ' ')
    allow_unfree="${allow_unfree:-false}"
    
    local bootloader
    bootloader=$(parse_nix_value "$profile_file" "bootloader" | tr -d '"')
    bootloader="${bootloader:-systemd-boot}"
    
    local channel
    channel=$(parse_nix_value "$profile_file" "channel" | tr -d '"')
    channel="${channel:-stable}"
    
    local desktop_env
    desktop_env=$(parse_desktop_env "$profile_file")
    
    local cpu
    cpu=$(parse_hardware_cpu "$profile_file")
    cpu="${cpu:-none}"
    
    local gpu
    gpu=$(parse_hardware_gpu "$profile_file")
    gpu="${gpu:-none}"
    
    local ram
    ram=$(parse_hardware_ram "$profile_file")
    
    local users_block
    users_block=$(parse_users_block "$profile_file")
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
    
    local package_modules
    package_modules=$(parse_package_modules "$profile_file")
    
    # ---- Write v1 modular configs ----
    
    # 1. System config (entry point)
    write_system_config "$system_type" "$host_name" "$timezone" "$users_block" "$bootloader"
    
    # 2. System manager
    write_system_manager_config "$system_type" "$allow_unfree" "$channel" "$bootloader"
    
    # 3. Network
    write_network_config "$host_name"
    
    # 4. Localization
    local locale
    locale=$(parse_nix_value "$profile_file" "locales" 2>/dev/null | tr -d '[]"' | sed 's/,/ /g' | head -1)
    locale="${locale:-en_US.UTF-8}"
    local keyboard_layout
    keyboard_layout=$(parse_nix_value "$profile_file" "keyboardLayout" | tr -d '"')
    keyboard_layout="${keyboard_layout:-us}"
    local keyboard_options
    keyboard_options=$(parse_nix_value "$profile_file" "keyboardOptions" | tr -d '"')
    write_localization_config "$locale" "$keyboard_layout" "$keyboard_options" "$timezone"
    
    # 5. Hardware
    write_hardware_config "$cpu" "$gpu" "$ram"
    
    # 6. Desktop
    if [[ -n "$desktop_env" ]]; then
        write_desktop_config "$desktop_env" "sddm" "wayland" "$desktop_env" "true" "pipewire"
        write_audio_config "pipewire"
    else
        write_desktop_disabled
    fi
    
    # 7. Packages
    if [[ -n "$package_modules" ]]; then
        read -ra mod_array <<< "$package_modules"
        write_packages_config "${mod_array[@]}"
    else
        write_packages_config
    fi
    
    log_success "Predefined profile applied successfully (v1 modular)"
    
    # Export system type for deployment
    export SYSTEM_TYPE="$system_type"
    
    # Deploy config
    deploy_config
}

# Export function
export -f setup_predefined_profile
