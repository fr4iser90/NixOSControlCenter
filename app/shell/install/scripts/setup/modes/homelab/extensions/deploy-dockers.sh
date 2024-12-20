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
    # Check docker user - only warn if not exists
    if ! id -u "${VIRT_USER}" >/dev/null 2>&1; then
        log_warn "Docker user ${VIRT_USER} does not exist yet - will be created after rebuild"
    fi

    # Check docker config - this should still be an error
    if [[ ! -d "${HOMELAB_DOCKER_DIR}" ]]; then
        log_error "No Docker configuration found in ${HOMELAB_DOCKER_DIR}"
        return 1
    fi
    
    return 0
}

create_deploy_script() {
    local deploy_script="$1"
    
    cat > "$deploy_script" << EOF
#!/usr/bin/env bash
set -euo pipefail

main() {
    echo "=== Docker Deployment ==="
    
    # Check docker service
    if ! systemctl is-active docker >/dev/null 2>&1; then
        echo "ERROR: Docker service not running"
        echo "Please reboot first"
        exit 1
    fi

    # Setup directories
    echo "Setting up docker directories..."
    DOCKER_HOME="/home/${VIRT_USER}/docker"
    
    # Backup if needed
    if [[ -d "\$DOCKER_HOME" ]]; then
        BACKUP="\${DOCKER_HOME}.backup_\$(date +%Y%m%d_%H%M%S)"
        echo "Creating backup at \$BACKUP"
        sudo mv "\$DOCKER_HOME" "\$BACKUP"
    fi
    
    # Create directory structure
    sudo mkdir -p "\$DOCKER_HOME"/{compose,data,config}
    
    # Copy configurations
    echo "Copying docker configuration..."
    sudo cp -r "${HOMELAB_DOCKER_DIR}/"* "\$DOCKER_HOME/"
    
    # Set permissions
    echo "Setting permissions..."
    sudo chown -R "${VIRT_USER}:${VIRT_USER}" "\$DOCKER_HOME"
    sudo chmod -R 755 "\$DOCKER_HOME"
    
    # Set sensitive file permissions
    echo "Setting sensitive file permissions..."
    sudo find "\$DOCKER_HOME" \\
        -type f \\( -name "*.key" -o -name "*.pem" -o -name "*.crt" \\) \\
        -exec chmod 600 {} \\;
    
    # Update configuration files
    echo "Updating configuration files..."
    sudo find "\$DOCKER_HOME" \\
        -type f \\( -name "*.yml" -o -name "*.env" \\) \\
        -exec sed -i \\
            -e "s|{{EMAIL}}|${HOMELAB_EMAIL}|g" \\
            -e "s|{{DOMAIN}}|${HOMELAB_DOMAIN}|g" \\
            -e "s|{{CERTEMAIL}}|${HOMELAB_CERT_EMAIL}|g" \\
            -e "s|{{USER}}|${VIRT_USER}|g" \\
            {} \\;
    
    echo "Docker configuration deployed successfully!"
}

main "\$@"
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