#!/usr/bin/env bash

deploy_docker_config() {
    log_section "Deploying Docker Configuration"
    
    # Prüfe benötigte Umgebungsvariablen
    for var in VIRT_USER USER_EMAIL USER_DOMAIN CERT_EMAIL; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable $var is not set"
            return 1
        fi
    done
    
    # Warte auf System-Neustart wenn nötig
    if ! systemctl is-active docker >/dev/null 2>&1; then
        log_warning "Docker service not running yet. Please reboot first."
        return 1
    }

    local virt_user="${VIRT_USER:-docker}"
    local docker_home="/home/${virt_user}"
    local docker_config="${docker_home}/docker"
    
    # Backup existierender Docker-Konfiguration
    if [ -d "$docker_config" ]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_dir="${docker_config}.backup_${timestamp}"
        log_info "Creating backup at ${backup_dir}"
        sudo mv "$docker_config" "$backup_dir"
    fi
    
    # Erstelle Docker-Verzeichnisstruktur
    log_info "Creating Docker directory structure"
    sudo mkdir -p "${docker_config}"/{compose,data,config}
    
    # Kopiere Docker-Konfiguration
    log_info "Deploying Docker configuration"
    sudo cp -r "${NIXOS_CONFIG_DIR}/docker/"* "${docker_config}/"
    
    # Setze Berechtigungen
    log_info "Setting permissions"
    sudo chown -R "${virt_user}:${virt_user}" "${docker_config}"
    sudo chmod -R 755 "${docker_config}"
    
    # Ersetze Platzhalter in Docker-Compose-Dateien
    log_info "Updating configuration files"
    find "${docker_config}" -type f -name "*.yml" -o -name "*.env" | while read -r file; do
        sudo sed -i \
            -e "s|{{EMAIL}}|${USER_EMAIL}|g" \
            -e "s|{{DOMAIN}}|${USER_DOMAIN}|g" \
            -e "s|{{CERTEMAIL}}|${CERT_EMAIL}|g" \
            -e "s|{{USER}}|${virt_user}|g" \
            "$file"
    done
    
    # Setze spezielle Berechtigungen für sensitive Dateien
    find "${docker_config}" -type f -name "*.key" -o -name "*.pem" -o -name "*.crt" | while read -r file; do
        sudo chmod 600 "$file"
    done
    
    log_success "Docker configuration deployed"
    log_info "You can now start your Docker services"
}

# Export function
export -f deploy_docker_config