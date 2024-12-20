#!/usr/bin/env bash

deploy_docker_config() {
    log_section "Deploying Docker Configuration"
    
    # Validate environment
    validate_environment || return 1
    
    # Create deployment script
    local hostname=$(hostname)
    local deploy_script="${NIXOS_CONFIG_DIR}/deploy-docker-${hostname}.sh"
    
    create_deploy_script "$deploy_script" || return 1
    
    return 0
}

validate_environment() {
    # Check docker user
    if ! id -u "${VIRT_USER}" >/dev/null 2>&1; then
        log_error "Docker user ${VIRT_USER} does not exist"
        log_info "Did setup_users run correctly?"
        return 1
    fi

    # Check docker config
    if [[ ! -d "${HOMELAB_DOCKER_DIR}" ]]; then
        log_error "No Docker configuration found in ${HOMELAB_DOCKER_DIR}"
        return 1
    fi
    
    return 0
}

create_deploy_script() {
    local deploy_script="$1"
    
    cat > "$deploy_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Source common functions
source "$(dirname "$0")/lib/logging.sh"

main() {
    log_section "Docker Deployment"
    
    # Check docker service
    check_docker_service || exit 1
    
    # Setup directories
    setup_directories || exit 1
    
    # Deploy configuration
    deploy_configuration || exit 1
    
    # Set permissions
    set_permissions || exit 1
    
    # Update configurations
    update_configurations || exit 1
    
    log_success "Docker configuration deployed successfully!"
}

check_docker_service() {
    if ! systemctl is-active docker >/dev/null 2>&1; then
        log_error "Docker service not running"
        log_info "Please reboot first"
        return 1
    fi
}

setup_directories() {
    local docker_dest="/home/${VIRT_USER}/docker"
    
    # Backup if needed
    if [[ -d "$docker_dest" ]]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup="${docker_dest}.backup_${timestamp}"
        log_info "Creating backup at $backup"
        sudo mv "$docker_dest" "$backup"
    fi
    
    # Create directories
    log_info "Creating docker directories"
    sudo mkdir -p "$docker_dest"/{compose,data,config}
    
    return 0
}

deploy_configuration() {
    local docker_dest="/home/${VIRT_USER}/docker"
    
    log_info "Copying docker configuration"
    sudo cp -r "${HOMELAB_DOCKER_DIR}/"* "$docker_dest/"
}

set_permissions() {
    local docker_dest="/home/${VIRT_USER}/docker"
    
    log_info "Setting directory permissions"
    sudo chown -R "${VIRT_USER}:${VIRT_USER}" "$docker_dest"
    sudo chmod -R 755 "$docker_dest"
    
    log_info "Setting sensitive file permissions"
    sudo find "$docker_dest" \
        -type f \( -name "*.key" -o -name "*.pem" -o -name "*.crt" \) \
        -exec chmod 600 {} \;
}

update_configurations() {
    local docker_dest="/home/${VIRT_USER}/docker"
    
    log_info "Updating configuration files"
    sudo find "$docker_dest" \
        -type f \( -name "*.yml" -o -name "*.env" \) \
        -exec sed -i \
            -e "s|{{EMAIL}}|${USER_EMAIL}|g" \
            -e "s|{{DOMAIN}}|${USER_DOMAIN}|g" \
            -e "s|{{CERTEMAIL}}|${CERT_EMAIL}|g" \
            -e "s|{{USER}}|${VIRT_USER}|g" \
            {} \;
}

main "$@"
EOF

    chmod +x "$deploy_script" || return 1
    return 0
}

# Export functions
export -f deploy_docker_config
export -f validate_environment
export -f create_deploy_script

# Check script execution
check_script_execution "HOMELAB_DOCKER_DIR" "deploy_docker_config"