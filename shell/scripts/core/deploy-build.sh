#!/usr/bin/env bash

deploy_config() {
    log_section "Deploying Configuration"
    
    # Basic deployment for all types
    deploy_base_config || return 1
    
    # Check if homelab-manager is enabled
    local has_homelab=false
    if [[ -f "$SYSTEM_CONFIG_FILE" ]]; then
        # Check if homelab block exists or homelab-manager feature is enabled
        if grep -q "homelab" "$SYSTEM_CONFIG_FILE" || \
           grep -q "homelab-manager.*=.*true" "$SYSTEM_CONFIG_FILE" 2>/dev/null || \
           [[ -f "$(dirname "$SYSTEM_CONFIG_FILE")/configs/features-config.nix" ]] && \
           grep -q "homelab-manager.*=.*true" "$(dirname "$SYSTEM_CONFIG_FILE")/configs/features-config.nix" 2>/dev/null; then
            has_homelab=true
        fi
    fi
    
    if [[ "$has_homelab" == "true" ]] && [[ -n "${VIRT_USER:-}" ]]; then
        show_homelab_completion_message || return 1
    else
        show_standard_completion_message || return 1
    fi
    
    return 0
}

deploy_base_config() {
    # Setup temp directory
    local nixos_dir="$HOME/.local/nixos"
    ensure_dir "$nixos_dir"
    
    # Copy configurations
    cp -r "${NIXOS_CONFIG_DIR}"/* "$nixos_dir/"
    
    # Copy system files
    local system_files=(
        "hardware-configuration.nix"
        "flake.lock"
        "flake.nix"
        ".system-config.previous.json"
    )
    
    for file in "${system_files[@]}"; do
        if [ -f "/etc/nixos/$file" ]; then
            log_info "Copying $file from system configuration"
            cp "/etc/nixos/$file" "$nixos_dir/"
        fi
    done
    
    # Copy secrets if they exist
    [ -d "/etc/nixos/secrets" ] && {
        log_info "Copying secrets directory"
        cp -r "/etc/nixos/secrets" "$nixos_dir/"
    }
    
    # Deploy directly
    log_info "Copying configuration..."
    cp -r "$nixos_dir"/* /etc/nixos/

    # Fix permissions
    log_info "Setting permissions..."
    chown -R root:root /etc/nixos/
    chmod -R 644 /etc/nixos/
    find /etc/nixos/ -type d -exec chmod 755 {} \;

    # Build and switch
    log_success "Build system..."
    # Get hostname from system-config.nix, fallback to system hostname
    local config_hostname
    if [ -f "$SYSTEM_CONFIG_FILE" ]; then
      config_hostname=$(grep -m 1 'hostName = ' "$SYSTEM_CONFIG_FILE" 2>/dev/null | sed 's/.*hostName = "\(.*\)";.*/\1/' || echo "$(hostname)")
    else
      config_hostname=$(hostname)
    fi
    nixos-rebuild switch --flake /etc/nixos#"${config_hostname}"


    # BREAKPOINT HERE!
    # Cleanup
    log_info "Cleaning up..."
    rm -rf "$nixos_dir"
    
    log_success "Build complete!"    #  
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