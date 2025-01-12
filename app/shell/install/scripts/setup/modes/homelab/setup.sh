#!/usr/bin/env bash

setup_homelab() {
    log_section "Homelab Setup"
    
    # 1. User Setup (macht bereits alles was wir brauchen)
    setup_homelab_config || return 1

    # 3. Deploy Docker before rebuilding
    # deploy_docker_config || return 1
    
    # 2. Deploy Config
    deploy_config


    
    log_success "Homelab setup complete"
    return 0
}

export -f setup_homelab