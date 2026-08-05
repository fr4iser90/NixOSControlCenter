#!/usr/bin/env bash

# =============================================================
# Config Writer Library - v2 Dual Layout Config System
# =============================================================
# Default layout: monolith (/etc/nixos/systemConfig.nix)
# Optional layout: split (/etc/nixos/systemConfig/**/config.nix)
#
# Set NCC_LAYOUT=split before writing to force split leaf files.
# =============================================================

# Common path constants + facade (see config-paths.sh / config-facade.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config-paths.sh
source "${SCRIPT_DIR}/config-paths.sh"
# shellcheck source=config-facade.sh
source "${SCRIPT_DIR}/config-facade.sh"

# Default new installs to monolith unless caller already chose a layout
if [[ -z "${NCC_LAYOUT:-}" ]]; then
  export NCC_LAYOUT="${NCC_DEFAULT_LAYOUT:-monolith}"
fi

# ---------- General helper ----------
# write_module_config is provided by config-facade.sh (layout-aware)

# ---------- System Manager (core/management/system-manager) ----------

write_system_manager_config() {
    local system_type="${1:-desktop}"
    local allow_unfree="${2:-false}"
    local channel="${3:-stable}"
    local bootloader="${4:-systemd-boot}"
    local build_log_level="${5:-minimal}"
    
    write_module_config "core/management/system-manager" "{
  # System Manager Configuration
  configVersion = \"2.0\";
  layout = \"${NCC_LAYOUT:-monolith}\";
  systemType = \"${system_type}\";
  allowUnfree = ${allow_unfree};
  system = {
    channel = \"${channel}\";
    bootloader = \"${bootloader}\";
  };
  buildLogLevel = \"${build_log_level}\";
}"
}

# ---------- System Config (v2: no legacy system-config.nix) ----------

write_system_config() {
    local system_type="${1:-desktop}"
    local host_name="${2:-nixos}"
    local timezone="${3:-Europe/Berlin}"
    local users_block="${4:-}"
    local bootloader="${5:-systemd-boot}"
    
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

    # Ensure layout target exists; do NOT write deprecated system-config.nix
    if declare -F ncc_dry_run >/dev/null 2>&1 && ncc_dry_run; then
        ncc_dry_skip "ensure config dirs" "${CONFIGS_BASE:-/etc/nixos/systemConfig}"
    else
        mkdir -p "$CONFIGS_BASE"
    fi
    if [[ -f "${SYSTEM_CONFIG_FILE:-}" ]]; then
        log_debug "Leaving legacy system-config.nix in place until config-check migrates it"
    fi

    # Users belong in core/base/user (split leaf or monolith nested path)
    write_user_config "$users_block"
    log_debug "Wrote user config via facade (layout=$(ncc_detect_layout))"
}

# ---------- Desktop (core/base/desktop) ----------

write_desktop_config() {
    local desktop_env="${1:-plasma}"
    local display_mgr="${2:-sddm}"
    local display_server="${3:-wayland}"
    local session="${4:-plasma}"
    local dark_mode="${5:-true}"
    local audio="${6:-pipewire}"
    local enable="${7:-true}"
    
    write_module_config "core/base/desktop" "{
  enable = ${enable};
  environment = \"${desktop_env}\";
  display = {
    manager = \"${display_mgr}\";
    server = \"${display_server}\";
    session = \"${session}\";
  };
  theme = {
    dark = ${dark_mode};
  };
  audio = \"${audio}\";
}"
}

# Disable desktop
write_desktop_disabled() {
    write_module_config "core/base/desktop" "{
  enable = false;
}"
}

# ---------- Hardware (core/base/hardware) ----------

write_hardware_config() {
    local cpu="${1:-none}"
    local gpu="${2:-none}"
    local memory_gb="${3:-}"
    
    if [[ -n "$memory_gb" ]]; then
        write_module_config "core/base/hardware" "{
  cpu = \"${cpu}\";
  gpu = \"${gpu}\";
  ram = {
    sizeGB = ${memory_gb};
  };
}"
    else
        write_module_config "core/base/hardware" "{
  cpu = \"${cpu}\";
  gpu = \"${gpu}\";
  ram.sizeGB = null;
}"
    fi
}

# ---------- Packages (core/base/packages) ----------

write_packages_config() {
    # All args are package module / set names → packageModules.
    # (Do not treat argv[0] as packages.preset — callers pass only module lists.)
    local modules=("$@")

    local modules_section=""
    if [[ ${#modules[@]} -gt 0 ]]; then
        modules_section="  packageModules = [
"
        for mod in "${modules[@]}"; do
            [[ -n "$mod" ]] && modules_section+="    \"${mod}\"
"
        done
        modules_section+="  ];
"
    else
        modules_section="  packageModules = [];
"
    fi

    write_module_config "core/base/packages" "{
${modules_section}  systemPackages = [];
  userPackages = {};
  docker.enable = false;
  docker.root = null;
}"
}

# ---------- Localization (core/base/localization) ----------

write_localization_config() {
    local locale="${1:-en_US.UTF-8}"
    local keyboard_layout="${2:-us}"
    local keyboard_options="${3:-}"
    local timezone="${4:-Europe/Berlin}"
    
    if [[ -n "$keyboard_options" ]]; then
        write_module_config "core/base/localization" "{
  locales = [ \"${locale}\" ];
  keyboardLayout = \"${keyboard_layout}\";
  keyboardOptions = \"${keyboard_options}\";
  timeZone = \"${timezone}\";
}"
    else
        write_module_config "core/base/localization" "{
  locales = [ \"${locale}\" ];
  keyboardLayout = \"${keyboard_layout}\";
  keyboardOptions = \"\";
  timeZone = \"${timezone}\";
}"
    fi
}

# ---------- Network (core/base/network) ----------

write_network_config() {
    local host_name="${1:-nixos}"
    local dns="${2:-default}"
    
    write_module_config "core/base/network" "{
  enable = true;
  networkManager.dns = \"${dns}\";
  hostName = \"${host_name}\";
  firewall.enable = true;
  firewall.trustedNetworks = [];
  services = {};
}"
}

# ---------- Users (core/base/user) ----------

write_user_config() {
    local users_block="$1"

    # Module config is flat: username → { role, ... } (same shape as getModuleConfig "user")
    write_module_config "core/base/user" "{
${users_block}
}"
}

# ---------- Hosting (core/base/localization - email/domain) ----------

write_hosting_config() {
    local email="$1"
    local domain="$2"
    
    if [[ -z "$email" && -z "$domain" ]]; then
        return 0
    fi
    
    local content="{"
    [[ -n "$email" ]] && content+="
  email = \"${email}\";"
    [[ -n "$domain" ]] && content+="
  domain = \"${domain}\";"
    content+="
}"
    
    write_module_config "core/base/localization" "$content"
}

# ---------- Overrides ----------

write_overrides_config() {
    local enable_ssh="${1:-null}"
    
    write_module_config "core/base/overrides" "{
  overrides = {
    enableSSH = ${enable_ssh};
  };
}"
}

# ---------- Logging ----------

write_logging_config() {
    local build_log_level="${1:-minimal}"
    
    write_module_config "core/base/logging" "{
  buildLogLevel = \"${build_log_level}\";
}"
}

# ---------- Homelab Feature ----------

write_homelab_config() {
    local homelab_type="${1:-single}"  # single | swarm
    local enable_email="${2:-false}"
    local enable_vm="${3:-false}"
    local swarm_role_arg="${4:-${swarm_role:-manager}}"

    local content="{"
    content+="
  homelab.enable = ${enable_email};"

    if [[ "$homelab_type" == "swarm" ]]; then
        content+="
  homelab.type = \"swarm\";"
        content+="
  homelab.role = \"${swarm_role_arg}\";"
    else
        content+="
  homelab.type = \"single\";"
    fi

    content+="
  homelab.virtualization = ${enable_vm};
}"

    write_module_config "modules/infrastructure/homelab-manager" "$content"
}

# ---------- SSH Server ----------

write_ssh_config() {
    local enable="${1:-false}"
    local port="${2:-22}"
    
    write_module_config "modules/security/ssh-server-manager" "{
  enable = ${enable};
  port = ${port};
}"
}

# ---------- VM Manager ----------

write_vm_config() {
    local enable="${1:-false}"
    
    write_module_config "modules/infrastructure/vm" "{
  enable = ${enable};
}"
}

# ---------- Bootentry Manager ----------

write_bootentry_config() {
    local enable="${1:-false}"
    
    write_module_config "modules/infrastructure/bootentry-manager" "{
  enable = ${enable};
}"
}

# ---------- Audio ----------

write_audio_config() {
    local audio="${1:-pipewire}"
    
    write_module_config "core/base/audio" "{
  audio = \"${audio}\";
}"
}

# ---------- Lock Manager ----------

write_lock_config() {
    local enable="${1:-false}"
    
    write_module_config "modules/system/lock-manager" "{
  enable = ${enable};
}"
}

# ---------- AI Workspace ----------

write_ai_workspace_config() {
    local enable="${1:-false}"
    
    write_module_config "modules/specialized/ai-workspace" "{
  enable = ${enable};
}"
}

# ---------- Clean old configs (migration helper) ----------

# Remove old-style config files that should not exist in v1
clean_old_configs() {
    local configs_dir="${CONFIGS_BASE}"
    local old_files=(
        "packages-config.nix"
        "desktop-config.nix"
        "localization-config.nix"
        "hardware-config.nix"
        "hosting-config.nix"
        "overrides-config.nix"
        "logging-config.nix"
        "features-config.nix"
        "bootentry-config.nix"
        "homelab-config.nix"
        "vm-config.nix"
        "ai-workspace-config.nix"
        "lock-config.nix"
        "ssh-config.nix"
    )
    
    for old_file in "${old_files[@]}"; do
        local full_path="${configs_dir}/${old_file}"
        if [[ -f "$full_path" ]]; then
            rm -f "$full_path"
            log_debug "Removed old config: ${old_file}"
        fi
    done
    
    log_debug "Old config cleanup complete"
}

# ---------- Export ----------

export -f write_module_config
export -f ncc_detect_layout
export -f ncc_write_module_config
export -f ncc_read_module_config
export -f ncc_set_module_enable
export -f ncc_ensure_layout
export -f ncc_module_config_path
export -f write_system_manager_config
export -f write_system_config
export -f write_desktop_config
export -f write_desktop_disabled
export -f write_hardware_config
export -f write_packages_config
export -f write_localization_config
export -f write_network_config
export -f write_user_config
export -f write_hosting_config
export -f write_overrides_config
export -f write_logging_config
export -f write_homelab_config
export -f write_ssh_config
export -f write_vm_config
export -f write_bootentry_config
export -f write_audio_config
export -f write_lock_config
export -f write_ai_workspace_config
export -f clean_old_configs
