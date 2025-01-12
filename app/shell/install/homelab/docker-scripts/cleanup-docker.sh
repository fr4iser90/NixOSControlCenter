#!/bin/bash

# Standard script setup - DO NOT MODIFY
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOCKER_SCRIPTS_DIR="$(dirname "$SCRIPT_PATH")"

source "${DOCKER_SCRIPTS_DIR}/lib/core/imports.sh"

print_header "Docker Cleanup"

safe_docker_cleanup() {
    print_status "Starting safe Docker cleanup..." "info"

    # 1. Compose-Projekte sauber herunterfahren
    print_status "Stopping Docker Compose projects..." "info"
    for category in "${MANAGEMENT_CATEGORIES[@]}"; do
        if [ -d "${DOCKER_BASE_DIR}/$category" ]; then
            print_status "Stopping services in $category..." "info"
            (cd "${DOCKER_BASE_DIR}/$category" && docker compose down) 2>/dev/null || true
        fi
    done

    # 2. Docker Cleanup
    print_status "Cleaning Docker resources..." "info"
    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm $(docker ps -aq) 2>/dev/null || true
    docker network rm $(docker network ls -q) 2>/dev/null || true
    docker volume rm $(docker volume ls -q) 2>/dev/null || true
    docker rmi $(docker images -q) 2>/dev/null || true
    docker system prune -f --volumes

    print_status "Safe cleanup completed" "success"
}

full_docker_cleanup() {
    print_status "Starting FULL Docker cleanup..." "warning"
    print_status "Note: Some files can only be removed by root user" "warning"

    # 1. Normale Cleanup
    safe_docker_cleanup
    
    # 2. Information über geschützte Dateien
    print_status "Protected files detected!" "warning"
    print_status "To completely remove all files:" "warning"
    print_status "1. Log out from docker user" "info"
    print_status "2. Log in as your admin user" "info"
    print_status "3. Run: sudo rm -rf ${DOCKER_BASE_DIR:?}/*" "info"
    
    print_status "Full cleanup completed (except protected files)" "success"
}

# Cleanup-Auswahl
echo "Choose cleanup type:"
echo "1) Safe cleanup (preserves important data)"
echo "2) Full cleanup (will need manual steps as root)"
read -p "Enter choice (1/2): " choice

case $choice in
    1)
        if prompt_confirmation "Run safe cleanup?"; then
            safe_docker_cleanup
        fi
        ;;
    2)
        if prompt_confirmation "WARNING: This will clean most Docker data, but protected files need manual removal. Continue?"; then
            full_docker_cleanup
        fi
        ;;
    *)
        print_status "Invalid choice" "error"
        exit 1
        ;;
esac
