#!/usr/bin/env bash

deploy_config() {
    log_section "Deploying Configuration"
    
    # Basic deployment for all types
    deploy_base_config || return 1
    
    # Special handling for homelab
    if [[ -z "${SYSTEM_TYPE:-}" ]]; then
        log_error "SYSTEM_TYPE is not set"
        return 1
    elif [[ "${SYSTEM_TYPE}" == "homelab" ]]; then
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
    log_info "Building system..."
    nixos-rebuild switch --flake /etc/nixos#$(hostname)

    # Cleanup
    log_info "Cleaning up..."
    rm -rf "$nixos_dir"
    
    log_success "Build complete!"
    return 0
}

show_standard_completion_message() {
    log_success "Configuration deployed"
    log_info "System will rebuild on next boot"
    log_info "Press Ctrl+D to exit the shell"
    return 0
}

show_homelab_completion_message() {
    local docker_script="${NIXOS_CONFIG_DIR}/deploy-docker-${hostname}.sh"
    
    log_success "Setup complete!"
    log_info "Please follow these steps:"
    echo "1. Exit this shell (Ctrl+D)"
    echo "2. Reboot the system"
    echo "3. After reboot, run: $docker_script"
    
    read -p "Press Enter to continue..."
    
    return 0
}

build_system() {
    deploy_config
}

# Export functions
export -f deploy_config
export -f deploy_base_config
export -f build_system
export -f show_standard_completion_message
export -f show_homelab_completion_message

# Check script execution
check_script_execution "NIXOS_CONFIG_DIR" "deploy_config"