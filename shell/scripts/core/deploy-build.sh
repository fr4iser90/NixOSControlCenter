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
    log_success "Build system..."
    nixos-rebuild switch --flake /etc/nixos#$(hostname)


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
   
    log_success "Building complete!"
    log_success "Use homelab-fetch as ${virt_user} to start docker homelab setup..."
    read -p "Do you want to switch to ${virt_user} user now? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        su - "${virt_user}"
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