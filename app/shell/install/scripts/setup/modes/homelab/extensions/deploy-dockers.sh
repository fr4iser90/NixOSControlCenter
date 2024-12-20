#!/usr/bin/env bash

deploy_docker_config() {
    log_section "Deploying Docker Configuration"
    
    # Validate environment
    validate_environment || return 1
    
    # Setup directories
    log_info "Setting up docker directories..."
    DOCKER_HOME="/home/${VIRT_USER}/docker"
    
    # Backup if needed
    if [[ -d "$DOCKER_HOME" ]]; then
        BACKUP="${DOCKER_HOME}.backup_$(date +%Y%m%d_%H%M%S)"
        log_info "Creating backup at $BACKUP"
        mv "$DOCKER_HOME" "$BACKUP"
    fi
    
    # Create directory structure
    mkdir -p "$DOCKER_HOME"/{compose,data,config}
    
    # Copy configurations
    log_info "Copying docker configuration..."
    cp -r "${HOMELAB_DOCKER_DIR}/"* "$DOCKER_HOME/"
    
    # Set permissions
    log_info "Setting permissions..."
    chown -R "${VIRT_USER}:${VIRT_USER}" "$DOCKER_HOME"
    chmod -R 755 "$DOCKER_HOME"
    
    # Set sensitive file permissions
    log_info "Setting sensitive file permissions..."
    find "$DOCKER_HOME" \
        -type f \( -name "*.key" -o -name "*.pem" -o -name "*.crt" \) \
        -exec chmod 600 {} \;
    
    # Update configuration files
    log_info "Updating configuration files..."
    find "$DOCKER_HOME" \
        -type f \( -name "*.yml" -o -name "*.env" \) \
        -exec sed -i \
            -e "s|{{EMAIL}}|${HOMELAB_EMAIL}|g" \
            -e "s|{{DOMAIN}}|${HOMELAB_DOMAIN}|g" \
            -e "s|{{CERTEMAIL}}|${HOMELAB_CERT_EMAIL}|g" \
            -e "s|{{USER}}|${VIRT_USER}|g" \
            {} \;
    
    log_success "Docker configuration deployed successfully!"
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



# Export functions
export -f deploy_docker_config
export -f validate_environment


# Check script execution
check_script_execution "HOMELAB_DOCKER_DIR" "deploy_docker_config"