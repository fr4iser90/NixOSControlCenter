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
    
    # Erstelle Build-Skript
    local hostname=$(hostname)
    local build_script="${NIXOS_CONFIG_DIR}/build-${hostname}.sh"
    
    # Prüfe ob Docker-Deployment nötig ist
    local docker_config=""
    if [[ -d "${NIXOS_CONFIG_DIR}/docker" ]]; then
        log_info "Docker configuration found, will deploy after system build..."
        docker_config="${NIXOS_CONFIG_DIR}/docker"
    fi
    
    cat > "$build_script" << EOF
#!/usr/bin/env bash
set -e  # Exit bei Fehlern

echo "Copying configuration..."
sudo cp -r $nixos_dir/* /etc/nixos/

echo "Building system..."
sudo nixos-rebuild switch --flake /etc/nixos#${hostname}

if [[ -n "$docker_config" ]]; then
    echo "Waiting for Docker service..."
    for i in {1..30}; do
        if systemctl is-active docker >/dev/null 2>&1; then
            break
        fi
        echo "Waiting for Docker to start... (\$i/30)"
        sleep 1
    done

    if ! systemctl is-active docker >/dev/null 2>&1; then
        echo "Docker service not ready. Please reboot and run:"
        echo "sudo cp -r $docker_config /home/docker/docker"
        exit 1
    fi

    echo "Setting up Docker configuration..."
    # Frage nach Docker-User wenn nicht gesetzt
    if [ -z "\${VIRT_USER}" ]; then
        read -p "Enter Docker user name [docker]: " VIRT_USER
        VIRT_USER=\${VIRT_USER:-docker}
    fi
    
    local docker_home="/home/\${VIRT_USER}"
    local docker_dest="\${docker_home}/docker"
    
    # Backup existierender Docker-Konfiguration
    if [ -d "\$docker_dest" ]; then
        local timestamp=\$(date +%Y%m%d_%H%M%S)
        local backup_dir="\${docker_dest}.backup_\${timestamp}"
        echo "Creating backup at \${backup_dir}"
        sudo mv "\$docker_dest" "\$backup_dir"
    fi
    
    # Erstelle Docker-Verzeichnisstruktur
    sudo mkdir -p "\${docker_dest}"/{compose,data,config}
    
    # Kopiere Docker-Konfiguration
    sudo cp -r "$docker_config"/* "\${docker_dest}/"
    
    # Setze Berechtigungen
    sudo chown -R "\${VIRT_USER}:\${VIRT_USER}" "\${docker_dest}"
    sudo chmod -R 755 "\${docker_dest}"
    
    echo "Docker configuration deployed!"
fi

echo "Cleaning up..."
rm -rf $nixos_dir

echo "Build complete!"
EOF
    
    chmod +x "$build_script"
    
    log_success "Configuration prepared"
    log_info "Please run the following script after exiting the shell:"
    echo
    echo "$build_script"
    echo
    log_info "Press Ctrl+D to exit the shell, then run the script"
    
    exit 0
}

build_system() {
    deploy_config
}

# Export functions
export -f deploy_config
export -f build_system