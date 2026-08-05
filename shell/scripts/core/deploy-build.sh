#!/usr/bin/env bash

deploy_config() {
    log_section "Deploying Configuration"

    local target="${SYSTEM_CONFIG_DIR:-/etc/nixos}"

    if declare -F ncc_dry_run >/dev/null 2>&1 && ncc_dry_run; then
        ncc_dry_skip "deploy_config" "$target (copy + nixos-rebuild switch)"
        log_success "[DRY-RUN] Deploy skipped — selection/path validated only"
        return 0
    fi
    
    # Basic deployment for all types
    deploy_base_config || return 1
    
    # Check if homelab-manager is enabled
    local has_homelab=false
    local hl_cfg="${target}/systemConfig/modules/infrastructure/homelab-manager/config.nix"
    if [[ -f "$SYSTEM_CONFIG_FILE" ]]; then
        if grep -q "homelab" "$SYSTEM_CONFIG_FILE" || \
           grep -q "homelab-manager.*=.*true" "$SYSTEM_CONFIG_FILE" 2>/dev/null || \
           { [[ -f "$hl_cfg" ]] && grep -q "homelab.*=.*true" "$hl_cfg" 2>/dev/null; }; then
            has_homelab=true
        fi
    elif [[ -f "$hl_cfg" ]] && grep -q "homelab.*=.*true" "$hl_cfg" 2>/dev/null; then
        has_homelab=true
    fi
    
    if [[ "$has_homelab" == "true" ]] && [[ -n "${VIRT_USER:-}" ]]; then
        # Non-interactive (tests / CI): skip su prompt
        if [[ -n "${NCC_DEPLOY_NONINTERACTIVE:-}" ]] || [[ ! -t 0 ]]; then
            show_standard_completion_message || return 1
        else
            show_homelab_completion_message || return 1
        fi
    else
        show_standard_completion_message || return 1
    fi
    
    return 0
}

deploy_base_config() {
    local target="${SYSTEM_CONFIG_DIR:-/etc/nixos}"
    local nixos_dir="${NCC_DEPLOY_STAGING_DIR:-$HOME/.local/nixos}"
    local source_dir="${NIXOS_CONFIG_DIR:?NIXOS_CONFIG_DIR is required}"

    ensure_dir "$nixos_dir"
    ensure_dir "$target"
    
    # Copy configurations from repo tree
    cp -r "${source_dir}"/* "$nixos_dir/"
    
    # Preserve machine-specific overlays from current system target
    local system_files=(
        "hardware-configuration.nix"
        "flake.lock"
        ".system-config.previous.json"
    )
    
    for file in "${system_files[@]}"; do
        if [ -f "$target/$file" ]; then
            log_info "Copying $file from system configuration"
            cp "$target/$file" "$nixos_dir/"
        fi
    done
    
    # Preserve secrets
    if [ -d "$target/secrets" ]; then
        log_info "Copying secrets directory"
        cp -r "$target/secrets" "$nixos_dir/"
    fi

    # Preserve installer-written systemConfig / monolith if present under target
    # (writers land here before deploy; must survive the repo overlay)
    if [ -f "$target/systemConfig.nix" ]; then
        cp "$target/systemConfig.nix" "$nixos_dir/"
    fi
    if [ -d "$target/systemConfig" ]; then
        rm -rf "$nixos_dir/systemConfig"
        cp -r "$target/systemConfig" "$nixos_dir/systemConfig"
    fi
    
    # Backup flake.nix from target before overwriting with repo version
    if [ -f "$target/flake.nix" ]; then
        backup_file "$target/flake.nix" || {
            log_warn "Failed to backup existing flake.nix, continuing anyway..."
        }
    fi
    
    # Deploy staging → system target
    log_info "Copying configuration to $target ..."
    cp -r "$nixos_dir"/* "$target/"

    # Fix permissions (skippable for non-root tests)
    if [[ "${NCC_DEPLOY_SKIP_PERMS:-0}" == "1" ]]; then
        log_info "Skipping permission fix (NCC_DEPLOY_SKIP_PERMS=1)"
    else
        log_info "Setting permissions..."
        chown -R root:root "$target/"
        chmod -R 644 "$target/"
        find "$target/" -type d -exec chmod 755 {} \;
    fi

    # Build and switch (skippable for copy-only tests)
    local config_hostname
    if [ -f "${MONOLITH_FILE:-}" ]; then
        config_hostname=$(grep -m 1 'hostName = ' "$MONOLITH_FILE" 2>/dev/null | sed 's/.*hostName = "\(.*\)";.*/\1/' || true)
    fi
    if [[ -z "${config_hostname:-}" ]] && [ -f "$SYSTEM_CONFIG_FILE" ]; then
        config_hostname=$(grep -m 1 'hostName = ' "$SYSTEM_CONFIG_FILE" 2>/dev/null | sed 's/.*hostName = "\(.*\)";.*/\1/' || true)
    fi
    config_hostname="${config_hostname:-$(hostname)}"

    if [[ "${NCC_DEPLOY_SKIP_REBUILD:-0}" == "1" ]]; then
        log_info "Skipping nixos-rebuild (NCC_DEPLOY_SKIP_REBUILD=1) host=$config_hostname"
    else
        log_success "Build system..."
        if [ "$EUID" -eq 0 ]; then
            HOME=/root nixos-rebuild switch --flake "${target}#${config_hostname}"
        else
            nixos-rebuild switch --flake "${target}#${config_hostname}"
        fi
    fi

    # Cleanup staging
    log_info "Cleaning up..."
    rm -rf "$nixos_dir"
    
    log_success "Build complete!"
    return 0
}

show_standard_completion_message() {
    log_success "Configuration deployed, if u changed your account, please login again"
    log_info "Press Ctrl+D to exit the shell"
    return 0
}

show_homelab_completion_message() {
    local virt_user="${VIRT_USER:-}"
    if [[ -z "$virt_user" ]]; then
        # Try to find virtualization or admin user from system-config.nix
        if [[ -f "$SYSTEM_CONFIG_FILE" ]]; then
            virt_user=$(grep -A 5 'role = "virtualization"' "$SYSTEM_CONFIG_FILE" 2>/dev/null | grep -oP '"\K[^"]+' | head -1 || \
                       grep -A 5 'role = "admin"' "$SYSTEM_CONFIG_FILE" 2>/dev/null | grep -oP '"\K[^"]+' | head -1 || \
                       echo "")
        fi
    fi
   
    log_success "Building complete!"
    if [[ -n "$virt_user" ]]; then
    log_success "Use homelab-fetch as ${virt_user} to start docker homelab setup..."
    read -p "Do you want to switch to ${virt_user} user now? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        su - "${virt_user}"
        fi
    else
        log_success "Homelab configuration deployed. Run 'homelab-fetch' as your virtualization or admin user to start setup."
    fi
    return 0
}

# Export functions
export -f deploy_config
export -f deploy_base_config
export -f show_standard_completion_message
export -f show_homelab_completion_message

# Check script execution
check_script_execution "NIXOS_CONFIG_DIR" "deploy_config"