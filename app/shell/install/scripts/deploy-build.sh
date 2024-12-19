#!/usr/bin/env bash

deploy_config() {
    log_section "Deploying Configuration"
    
    # Bereite Konfiguration vor
    local nixos_dir="$HOME/.local/nixos"
    rm -rf "$nixos_dir"
    mkdir -p "$nixos_dir"
    
    # Kopiere Konfigurationsdateien
    cp -r "${NIXOS_CONFIG_DIR}"/* "$nixos_dir/"
    
    # Kopiere wichtige Dateien aus /etc/nixos
    for file in "hardware-configuration.nix" "flake.lock" "flake.nix" ".system-config.previous.json"; do
        if [ -f "/etc/nixos/$file" ]; then
            log_info "Copying $file from system configuration"
            cp "/etc/nixos/$file" "$nixos_dir/"
        fi
    done
    
    # Kopiere secrets
    if [ -d "/etc/nixos/secrets" ]; then
        log_info "Copying secrets directory"
        cp -r "/etc/nixos/secrets" "$nixos_dir/"
    fi
    
    log_success "Configuration prepared"
    log_info "Please run the following commands manually after exiting the shell:"
    echo
    echo "sudo cp -r $nixos_dir/* /etc/nixos/"
    echo "sudo nixos-rebuild switch --flake /etc/nixos#Hostname"
    echo "rm -rf $nixos_dir"
    echo
    log_info "Press any key to exit the shell..."
    read -n 1
    exit 0
}

build_system() {
    deploy_config
}

# Export functions
export -f deploy_config
export -f build_system