#!/usr/bin/env bash

# =============================================================
# Preset Profile Loader - v1 Modular Config System
# =============================================================
# Reads preset profile files and converts them to v1 modular structure
# Uses config-writer.sh for all config file creation
# =============================================================

# Parse a scalar from the SAME line: key = value;
# Handles: "str", null, true/false, bare words
parse_nix_value() {
    local file="$1"
    local key="$2"
    local line value
    line=$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null | head -1) || true
    [[ -n "$line" ]] || { echo ""; return 0; }
    value="${line#*=}"
    value="${value%%;*}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    # Strip surrounding quotes
    if [[ "$value" =~ ^\".*\"$ ]]; then
        value="${value:1:-1}"
    fi
    echo "$value"
}

# Parse packageModules = [ ... ]; — only quoted "module" names (never comments)
parse_package_modules() {
    local file="$1"
    # Empty one-liner
    if grep -qE '^[[:space:]]*packageModules[[:space:]]*=[[:space:]]*\[[[:space:]]*\][[:space:]]*;' "$file"; then
        echo ""
        return 0
    fi
    local block
    block=$(awk '
      /^[[:space:]]*packageModules[[:space:]]*=[[:space:]]*\[/ {grab=1}
      grab {print}
      grab && /\][[:space:]]*;/ {exit}
    ' "$file")
    # Extract only "quoted" identifiers
    echo "$block" | grep -oE '"[^"]+"' | tr -d '"' | tr '\n' ' ' | sed 's/[[:space:]]*$//'
}

# Parse users block from a Nix config file
parse_users_block() {
    local file="$1"
    local in_users=0
    local brace_count=0
    local users_block=""

    # Empty users = {};
    if grep -qE '^[[:space:]]*users[[:space:]]*=[[:space:]]*\{[[:space:]]*\}[[:space:]]*;' "$file"; then
        echo ""
        return 0
    fi

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*users[[:space:]]*=[[:space:]]*\{ ]]; then
            in_users=1
            # count braces on opening line after =
            local rest="${line#*=}"
            brace_count=$(echo "$rest" | tr -cd '{' | wc -c)
            brace_count=$((brace_count - $(echo "$rest" | tr -cd '}' | wc -c)))
            if [[ $brace_count -le 0 ]]; then
                break
            fi
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

# First desktop.environment = "..." inside desktop = { }
parse_desktop_env() {
    local file="$1"
    local env
    env=$(awk '
      /^[[:space:]]*desktop[[:space:]]*=[[:space:]]*\{/ {in_de=1}
      in_de && /^[[:space:]]*environment[[:space:]]*=/ {
        if (match($0, /"[^"]+"/)) {
          print substr($0, RSTART+1, RLENGTH-2)
          exit
        }
        if (match($0, /=[[:space:]]*null/)) { print ""; exit }
      }
      in_de && /^[[:space:]]*\};[[:space:]]*$/ { exit }
    ' "$file")
    echo "$env"
}

parse_hardware_cpu() {
    parse_nix_value "$1" "cpu"
}

parse_hardware_gpu() {
    parse_nix_value "$1" "gpu"
}

parse_hardware_ram() {
    local file="$1"
    local ram
    ram=$(grep -E '^[[:space:]]*sizeGB[[:space:]]*=' "$file" 2>/dev/null | head -1 \
        | sed -E 's/^[^=]+=[[:space:]]*//; s/;[[:space:]]*$//; s/[[:space:]]//g')
    echo "$ram"
}

parse_locales_first() {
    local file="$1"
    # locales = [ "en_US.UTF-8" ];
    local line
    line=$(grep -E '^[[:space:]]*locales[[:space:]]*=' "$file" 2>/dev/null | head -1) || true
    echo "$line" | grep -oE '"[^"]+"' | head -1 | tr -d '"'
}

ncc_primary_install_user() {
    local u="${SUDO_USER:-}"
    if [[ -z "$u" || "$u" == "root" ]]; then
        u="$(logname 2>/dev/null || true)"
    fi
    if [[ -z "$u" || "$u" == "root" ]]; then
        u="$(whoami 2>/dev/null || echo user)"
    fi
    if [[ "$u" == "root" ]]; then
        u="user"
    fi
    echo "$u"
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

    local system_type host_name timezone allow_unfree bootloader channel
    local desktop_env cpu gpu ram users_block package_modules

    system_type=$(parse_nix_value "$profile_file" "systemType")
    system_type="${system_type:-desktop}"
    [[ "$system_type" == "null" ]] && system_type="desktop"

    host_name=$(parse_nix_value "$profile_file" "hostName")
    if [[ -z "$host_name" || "$host_name" == "null" ]]; then
        host_name="$(hostname)"
    fi

    timezone=$(parse_nix_value "$profile_file" "timeZone")
    timezone="${timezone:-Europe/Berlin}"
    [[ "$timezone" == "null" ]] && timezone="Europe/Berlin"

    allow_unfree=$(parse_nix_value "$profile_file" "allowUnfree")
    allow_unfree="${allow_unfree:-false}"

    bootloader=$(parse_nix_value "$profile_file" "bootloader")
    bootloader="${bootloader:-systemd-boot}"
    [[ "$bootloader" == "null" ]] && bootloader="systemd-boot"

    channel=$(parse_nix_value "$profile_file" "channel")
    channel="${channel:-stable}"
    [[ "$channel" == "null" ]] && channel="stable"

    desktop_env=$(parse_desktop_env "$profile_file")
    [[ "$desktop_env" == "null" ]] && desktop_env=""

    # Hardware: keep live detection when preset only has placeholders (null/none/empty).
    # Explicit profile values (e.g. jetson) still win.
    if [[ -z "${CPU_VENDOR:-}" ]] && declare -F check_cpu_info >/dev/null 2>&1; then
        check_cpu_info || true
    fi
    if [[ -z "${GPU_CONFIG:-}" ]] && declare -F check_gpu_info >/dev/null 2>&1; then
        check_gpu_info || true
    fi

    cpu=$(parse_hardware_cpu "$profile_file")
    if [[ -z "$cpu" || "$cpu" == "null" || "$cpu" == "none" ]]; then
        cpu="${CPU_VENDOR:-none}"
    fi

    gpu=$(parse_hardware_gpu "$profile_file")
    if [[ -z "$gpu" || "$gpu" == "null" || "$gpu" == "none" ]]; then
        gpu="${GPU_CONFIG:-none}"
    fi

    ram=$(parse_hardware_ram "$profile_file")
    [[ "$ram" == "null" ]] && ram=""
    if [[ -z "$ram" && -n "${MEMORY_GB:-}" ]]; then
        ram="$MEMORY_GB"
    fi

    users_block=$(parse_users_block "$profile_file")
    if [[ -z "$users_block" ]]; then
        local current_user current_shell
        current_user=$(ncc_primary_install_user)
        current_shell=$(basename "$(getent passwd "$current_user" 2>/dev/null | cut -d: -f7)" 2>/dev/null || echo "bash")
        users_block="    \"$current_user\" = {
      role = \"admin\";
      defaultShell = \"$current_shell\";
      autoLogin = false;
    };"
    fi

    package_modules=$(parse_package_modules "$profile_file")

    log_info "Parsed preset: type=$system_type host=$host_name de=${desktop_env:-none} packages=[${package_modules}]"
    log_info "Hardware: cpu=$cpu gpu=$gpu ram=${ram:-null}"

    # ---- Write v1 modular configs ----

    write_system_config "$system_type" "$host_name" "$timezone" "$users_block" "$bootloader"
    write_system_manager_config "$system_type" "$allow_unfree" "$channel" "$bootloader"
    write_network_config "$host_name"

    local locale keyboard_layout keyboard_options
    locale=$(parse_locales_first "$profile_file")
    locale="${locale:-en_US.UTF-8}"
    keyboard_layout=$(parse_nix_value "$profile_file" "keyboardLayout")
    keyboard_layout="${keyboard_layout:-us}"
    [[ "$keyboard_layout" == "null" ]] && keyboard_layout="us"
    keyboard_options=$(parse_nix_value "$profile_file" "keyboardOptions")
    [[ "$keyboard_options" == "null" ]] && keyboard_options=""
    write_localization_config "$locale" "$keyboard_layout" "$keyboard_options" "$timezone"

    write_hardware_config "$cpu" "$gpu" "$ram"

    if [[ -n "$desktop_env" ]]; then
        write_desktop_config "$desktop_env" "sddm" "wayland" "$desktop_env" "true" "pipewire"
        write_audio_config "pipewire"
    else
        write_desktop_disabled
    fi

    # Packages: GUI/TUI answers are authoritative when PACKAGE_MODULES or BROWSERS
    # is present (empty touched answers file must not skip the profile write).
    local answers_file="${NCC_GUI_ANSWERS_FILE:-}"
    local have_gui_pkg=false
    if [[ -n "$answers_file" && -f "$answers_file" ]] && declare -F ncc_gui_answer >/dev/null 2>&1; then
        if ncc_gui_answer PACKAGE_MODULES >/dev/null 2>&1 || ncc_gui_answer BROWSERS >/dev/null 2>&1; then
            have_gui_pkg=true
        fi
    fi
    if $have_gui_pkg && declare -F ncc_apply_gui_package_modules >/dev/null 2>&1; then
        log_info "Applying package selection from answers: $answers_file"
        ncc_apply_gui_package_modules "$package_modules" || return 1
    else
        export PACKAGE_SYSTEM_PACKAGES=""
        if [[ -n "$package_modules" ]]; then
            # shellcheck disable=SC2206
            local mod_array=($package_modules)
            write_packages_config "${mod_array[@]}" || return 1
        else
            write_packages_config || return 1
        fi
        unset PACKAGE_SYSTEM_PACKAGES 2>/dev/null || true
    fi

    # Steam / Brave / etc. need allowUnfree — set automatically from selection
    local unfree_tokens=()
    if $have_gui_pkg; then
        local gui_mods gui_browsers
        gui_mods=$(ncc_gui_answer PACKAGE_MODULES 2>/dev/null || true)
        gui_browsers=$(ncc_gui_answer BROWSERS 2>/dev/null || true)
        # shellcheck disable=SC2206
        unfree_tokens=($gui_mods $gui_browsers)
    else
        # shellcheck disable=SC2206
        unfree_tokens=($package_modules)
    fi
    if declare -F ncc_allow_unfree_for_tokens >/dev/null 2>&1; then
        ncc_allow_unfree_for_tokens "${unfree_tokens[@]}" || true
    fi

    if declare -F ncc_apply_gui_admin_user >/dev/null 2>&1; then
        ncc_apply_gui_admin_user || true
    fi

    log_success "Predefined profile applied successfully (v1 modular)"

    export SYSTEM_TYPE="$system_type"
    deploy_config || return 1
}

export -f parse_nix_value
export -f parse_package_modules
export -f parse_users_block
export -f parse_desktop_env
export -f setup_predefined_profile
