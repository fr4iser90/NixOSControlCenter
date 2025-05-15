#!/usr/bin/env bash

# Placeholder for Hackathon Server setup script

log_info "Starting Hackathon Server setup..."

setup_hackathon() {
    log_section "Hackathon Server Setup"
    
    # 1. Basic Configuration
    setup_hackathon_config || return 1
    
    # 2. System Level Setup
    setup_system_requirements || return 1
    
    # 3. Gateway Setup (Traefik + CrowdSec)
    setup_gateway || return 1
    
    # 4. Hackathon Services Setup
    setup_hackathon_services || return 1
    
    log_success "Hackathon Server setup complete"
    return 0
}

setup_system_requirements() {
    log_section "Setting up system requirements"
    
    # Ensure required packages are installed
    local required_packages=(
        "docker"
        "docker-compose"
        "git"
        "curl"
        "jq"
    )
    
    for pkg in "${required_packages[@]}"; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            log_info "Installing $pkg..."
            nix-env -iA "nixos.$pkg" || return 1
        fi
    done
    
    # Enable and start required services
    systemctl enable docker || return 1
    systemctl start docker || return 1
    
    return 0
}

setup_gateway() {
    log_section "Setting up Gateway (Traefik + CrowdSec)"
    
    # Create required directories
    local dirs=(
        "/etc/nixos/hackathon/gateway"
        "/etc/nixos/hackathon/gateway/traefik"
        "/etc/nixos/hackathon/gateway/crowdsec"
        "/var/log/traefik"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir" || return 1
    done
    
    # Copy Gateway configuration
    cp -r "${SCRIPT_DIR}/../../NCC-Hackathon/docker/gateway-management/traefik-crowdsec/"* "/etc/nixos/hackathon/gateway/" || return 1
    
    # Set up environment files
    cd "/etc/nixos/hackathon/gateway" || return 1
    
    # Update Traefik environment
    ./update-traefik-env.sh || return 1
    
    # Update CrowdSec environment
    ./update-crowdsec-env.sh || return 1
    
    # Start Gateway services
    docker-compose up -d || return 1
    
    return 0
}

setup_hackathon_services() {
    log_section "Setting up Hackathon services"
    
    # Create required directories
    local dirs=(
        "/etc/nixos/hackathon/services"
        "/etc/nixos/hackathon/data"
        "/etc/nixos/hackathon/templates"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir" || return 1
    done
    
    # Copy service configurations
    cp -r "${SCRIPT_DIR}/../../NCC-Hackathon/docker/api" "/etc/nixos/hackathon/services/" || return 1
    cp -r "${SCRIPT_DIR}/../../NCC-Hackathon/docker/frontend" "/etc/nixos/hackathon/services/" || return 1
    cp -r "${SCRIPT_DIR}/../../NCC-Hackathon/docker/database" "/etc/nixos/hackathon/services/" || return 1
    cp -r "${SCRIPT_DIR}/../../NCC-Hackathon/templates/"* "/etc/nixos/hackathon/templates/" || return 1
    
    # Create docker-compose.yml for Hackathon services
    cat > "/etc/nixos/hackathon/services/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  api:
    build: ./api
    container_name: hackathon-api
    restart: unless-stopped
    depends_on:
      - postgres
    environment:
      - DATABASE_URL=postgresql://hackathon:hackathon@postgres:5432/hackathon
      - JWT_SECRET=${JWT_SECRET}
      - ADMIN_EMAIL=${ADMIN_EMAIL}
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(`api.${DOMAIN}`)"
      - "traefik.http.routers.api.entrypoints=websecure"
      - "traefik.http.routers.api.tls=true"
      - "traefik.http.routers.api.tls.certresolver=http_resolver"
      - "traefik.http.services.api.loadbalancer.server.port=8000"
      - "traefik.http.routers.api.middlewares=security-headers@docker"

  frontend:
    build: ./frontend
    container_name: hackathon-frontend
    restart: unless-stopped
    depends_on:
      - api
    environment:
      - REACT_APP_API_URL=https://api.${DOMAIN}
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.frontend.rule=Host(`${DOMAIN}`)"
      - "traefik.http.routers.frontend.entrypoints=websecure"
      - "traefik.http.routers.frontend.tls=true"
      - "traefik.http.routers.frontend.tls.certresolver=http_resolver"
      - "traefik.http.services.frontend.loadbalancer.server.port=3000"
      - "traefik.http.routers.frontend.middlewares=security-headers@docker"

  postgres:
    build: ./database
    container_name: hackathon-postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=hackathon
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - POSTGRES_DB=hackathon
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - proxy

networks:
  proxy:
    external: true

volumes:
  postgres_data:
EOF
    
    # Create .env file
    cat > "/etc/nixos/hackathon/services/.env" << EOF
DOMAIN=${HACKATHON_DOMAIN}
ADMIN_EMAIL=${HACKATHON_EMAIL}
JWT_SECRET=$(openssl rand -base64 32)
DB_PASSWORD=$(openssl rand -base64 32)
EOF
    
    # Start Hackathon services
    cd "/etc/nixos/hackathon/services" || return 1
    docker-compose up -d || return 1
    
    return 0
}

export -f setup_hackathon
export -f setup_system_requirements
export -f setup_gateway
export -f setup_hackathon_services

log_info "Hackathon Server setup script finished (placeholder)." 