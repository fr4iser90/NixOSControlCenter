#!/usr/bin/env bash

deploy_docker_config() {
    log_section "Deploying Docker Configuration"
    
    # Validate environment
    validate_environment || return 1
    
    # Setup directories
    log_info "Setting up docker directories..."
    DOCKER_HOME="/home/${VIRT_USER}"
    
    # Backup if needed
    if [[ -d "$DOCKER_HOME" ]]; then
        BACKUP="${DOCKER_HOME}.backup_$(date +%Y%m%d_%H%M%S)"
        log_info "Creating backup at $BACKUP"
        mv "$DOCKER_HOME" "$BACKUP"
    fi
    
#     # Create directory structure
#     mkdir -p "$DOCKER_HOME"/{volumes,config}
    
#     # Copy configurations
#     log_info "Copying docker configuration..."
#     cp -r "${HOMELAB_DIR}/"* "$DOCKER_HOME/"
    

#     # Set temporary permissions - SECURITY WARNING!
#     log_info "Setting temporary permissions..."
#     log_warn "WARNING: Setting full access (777) for all users!"
#     log_warn "This is temporary and must be fixed by docker user after system setup!"
#     chmod -R 777 "$DOCKER_HOME"  # TEMPORARY: Full access for all until docker user exists
    
#     # Create reminder file
#     cat > "$DOCKER_HOME/SECURITY_README.txt" << EOF
# SECURITY WARNING!
# ================
# This directory currently has full access permissions (777) for all users.
# This is temporary and must be fixed after system setup by running:

# cd ~/docker-scripts
# ./init-homelab.sh

# This will set proper permissions for all files and directories.
# EOF
    
    
    sleep 1
    # Update configuration files
    log_info "Updating configuration files..."
    find "$DOCKER_HOME" \
        -type f \( -name "*.yml" -o -name "*.env" \) \
        -exec sed -i \
            -e "s|{{EMAIL}}|${HOMELAB_EMAIL}|g" \
            -e "s|{{DOMAIN}}|${HOMELAB_DOMAIN}|g" \
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
    if [[ ! -d "${HOMELAB_DIR}" ]]; then
        log_error "No Docker configuration found in ${HOMELAB_DIR}"
        return 1
    fi
    
    return 0
}



# Export functions
export -f deploy_docker_config
export -f validate_environment


# Check script execution
check_script_execution "HOMELAB_DIR" "deploy_docker_config"