#!/usr/bin/env bash

deploy_docker_config() {
    log_section "Deploying Docker Configuration"
    
    # Prüfe ob Docker-Konfiguration existiert
    if [[ ! -d "${NIXOS_CONFIG_DIR}/docker" ]]; then
        log_error "No Docker configuration found in ${NIXOS_CONFIG_DIR}/docker"
        return 1
    fi

    # Erstelle temporäres Verzeichnis
    local docker_temp="$HOME/.local/docker-temp"
    rm -rf "$docker_temp"
    mkdir -p "$docker_temp"

    # Kopiere Docker-Konfiguration
    cp -r "${NIXOS_CONFIG_DIR}/docker/"* "$docker_temp/"

    # Erstelle Docker-Deploy-Skript
    local hostname=$(hostname)
    local deploy_script="${NIXOS_CONFIG_DIR}/deploy-docker-${hostname}.sh"
    
    cat > "$deploy_script" << EOF
#!/usr/bin/env bash
set -e  # Exit bei Fehlern

# Prüfe Docker-Service
if ! systemctl is-active docker >/dev/null 2>&1; then
    echo "Docker service not running. Please reboot first."
    exit 1
fi

# Frage nach Variablen
read -p "Enter Docker user name [docker]: " VIRT_USER
VIRT_USER=\${VIRT_USER:-docker}
read -p "Enter email address: " USER_EMAIL
read -p "Enter domain: " USER_DOMAIN
read -p "Enter certificate email: " CERT_EMAIL

# Prüfe Variablen
for var in VIRT_USER USER_EMAIL USER_DOMAIN CERT_EMAIL; do
    if [[ -z "\${!var}" ]]; then
        echo "Error: \$var is required"
        exit 1
    fi
done

# Setup Docker-Verzeichnisse
docker_home="/home/\${VIRT_USER}"
docker_dest="\${docker_home}/docker"

# Backup wenn nötig
if [ -d "\$docker_dest" ]; then
    timestamp=\$(date +%Y%m%d_%H%M%S)
    backup_dir="\${docker_dest}.backup_\${timestamp}"
    echo "Creating backup at \${backup_dir}"
    sudo mv "\$docker_dest" "\$backup_dir"
fi

# Erstelle Struktur
echo "Creating Docker directory structure"
sudo mkdir -p "\${docker_dest}"/{compose,data,config}

# Kopiere Konfiguration
echo "Deploying Docker configuration"
sudo cp -r "$docker_temp"/* "\${docker_dest}/"

# Setze Berechtigungen
echo "Setting permissions"
sudo chown -R "\${VIRT_USER}:\${VIRT_USER}" "\${docker_dest}"
sudo chmod -R 755 "\${docker_dest}"

# Ersetze Platzhalter
echo "Updating configuration files"
find "\${docker_dest}" -type f -name "*.yml" -o -name "*.env" | while read -r file; do
    sudo sed -i \
        -e "s|{{EMAIL}}|\${USER_EMAIL}|g" \
        -e "s|{{DOMAIN}}|\${USER_DOMAIN}|g" \
        -e "s|{{CERTEMAIL}}|\${CERT_EMAIL}|g" \
        -e "s|{{USER}}|\${VIRT_USER}|g" \
        "\$file"
done

# Setze Berechtigungen für sensitive Dateien
find "\${docker_dest}" -type f -name "*.key" -o -name "*.pem" -o -name "*.crt" | while read -r file; do
    sudo chmod 600 "\$file"
done

# Cleanup
rm -rf "$docker_temp"

echo "Docker configuration deployed successfully!"
EOF

    chmod +x "$deploy_script"
    
    log_success "Docker deployment script prepared"
    log_info "Please run the following script after system rebuild and reboot:"
    echo
    echo "$deploy_script"
    echo
    
    return 0
}

# Export function
export -f deploy_docker_config