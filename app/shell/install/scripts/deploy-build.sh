#!/usr/bin/env bash

deploy_config() {
    log_section "Deploying Configuration"
    
    # Backup von /etc/nixos
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="/etc/nixos.backup_${timestamp}"
    
    log_info "Creating backup at ${backup_dir}"
    sudo cp -r /etc/nixos "${backup_dir}"
    
    # Hardware-Config sichern
    local hardware_config="/etc/nixos/hardware-configuration.nix"
    if [ -f "$hardware_config" ]; then
        log_info "Preserving hardware configuration"
        sudo cp "$hardware_config" "/tmp/hardware-configuration.nix"
    fi
    
    # Kopiere neue Konfiguration
    log_info "Deploying new configuration"
    sudo rm -rf /etc/nixos/*.nix
    sudo cp -r "${NIXOS_CONFIG_DIR}"/*.nix /etc/nixos/
    
    # Hardware-Config wiederherstellen
    if [ -f "/tmp/hardware-configuration.nix" ]; then
        sudo mv "/tmp/hardware-configuration.nix" "$hardware_config"
    fi
    
    # Secrets und Custom-Ordner nicht überschreiben
    log_info "Preserving secrets and custom configurations"
    for dir in "secrets" "custom"; do
        if [ -d "/etc/nixos/$dir" ]; then
            log_info "Keeping existing $dir directory"
        elif [ -d "${NIXOS_CONFIG_DIR}/$dir" ]; then
            sudo cp -r "${NIXOS_CONFIG_DIR}/$dir" /etc/nixos/
        fi
    done
    
    log_success "Configuration deployed to /etc/nixos"
}

build_system() {
    log_section "Building System"
    
    # Führe User-Check durch
    check_user_passwords || return 1
    
    local hostname=$(hostname)
    log_info "Building configuration for $hostname"
    
    if sudo nixos-rebuild switch --flake "/etc/nixos#${hostname}"; then
        log_success "System successfully rebuilt with flake for $hostname"
    else
        log_error "System rebuild failed"
        return 1
    fi
}

# Export functions
export -f deploy_config
export -f build_system