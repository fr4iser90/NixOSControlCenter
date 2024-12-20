#!/usr/bin/env bash

deploy_docker_config() {
    log_section "Deploying Docker Configuration"
    
    # Prüfe ob der Docker-User existiert
    if ! id -u "${VIRT_USER}" >/dev/null 2>&1; then
        log_error "Docker user ${VIRT_USER} does not exist. Did setup_users run correctly?"
        return 1
    fi

    # Prüfe ob Docker-Konfiguration existiert
    if [[ ! -d "${HOMELAB_SETUP_DIR}" ]]; then
        log_error "No Docker configuration found in ${HOMELAB_SETUP_DIR}"
        return 1
    fi

    # Erstelle Docker-Deploy-Skript
    local hostname=$(hostname)
    local deploy_script="${NIXOS_CONFIG_DIR}/deploy-docker-${hostname}.sh"
    
    cat > "$deploy_script" << EOF
#!/usr/bin/env bash
set -e

# Prüfe Docker-Service
if ! systemctl is-active docker >/dev/null 2>&1; then
    echo "Docker service not running. Please reboot first."
    exit 1
fi

# Setup Docker-Verzeichnisse
docker_dest="/home/${VIRT_USER}/docker"

# Backup wenn nötig
if [ -d "\$docker_dest" ]; then
    timestamp=\$(date +%Y%m%d_%H%M%S)
    echo "Creating backup at \${docker_dest}.backup_\${timestamp}"
    sudo mv "\$docker_dest" "\${docker_dest}.backup_\${timestamp}"
fi

# Erstelle und kopiere Docker-Konfiguration
echo "Deploying Docker configuration"
sudo mkdir -p "\$docker_dest"/{compose,data,config}
sudo cp -r "${HOMELAB_SETUP_DIR}/"* "\$docker_dest/"

# Setze Berechtigungen
echo "Setting permissions"
sudo chown -R "${VIRT_USER}:${VIRT_USER}" "\$docker_dest"
sudo chmod -R 755 "\$docker_dest"
sudo find "\$docker_dest" -type f -name "*.key" -o -name "*.pem" -o -name "*.crt" -exec chmod 600 {} \;

# Ersetze Platzhalter
echo "Updating configuration files"
sudo find "\$docker_dest" -type f -name "*.yml" -o -name "*.env" -exec sed -i \
    -e "s|{{EMAIL}}|${USER_EMAIL}|g" \
    -e "s|{{DOMAIN}}|${USER_DOMAIN}|g" \
    -e "s|{{CERTEMAIL}}|${CERT_EMAIL}|g" \
    -e "s|{{USER}}|${VIRT_USER}|g" {} \;

echo "Docker configuration deployed successfully!"
EOF

    chmod +x "$deploy_script"
    
    log_success "Docker deployment script prepared"
    log_info "Please run the following script after system rebuild and reboot:"
    echo "$deploy_script"
    
    return 0
}

export -f deploy_docker_config