#!/usr/bin/env bash

# Lade gemeinsame Funktionen
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/colors.sh"

# Interrupt Handler
on_interrupt() {
    error "\nScript interrupted. Aborting."
    exit 1
}

trap 'on_interrupt' SIGINT

# Dependency Check Funktion
check_and_install() {
    local package="$1"
    local command="$2"
    
    if ! command -v "$command" > /dev/null; then
        warning "$package is not installed (command: $command)"
        read -p "Do you want to proceed with installing $package? [Y/n]: " response
        response=${response:-y}
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            info "Installing $package..."
            if ! nix-env -iA nixos."$package"; then
                error "$package installation failed!"
                return 1
            fi
            success "$package installed successfully"
        else
            error "$package is required but installation was declined"
            return 1
        fi
    else
        info "$package is already installed"
    fi
}

check_dependencies() {
    info "Checking required dependencies..."
    
    # Nur die wirklich benötigten Dependencies
    check_and_install "pciutils" "lspci" || return 1
    check_and_install "mkpasswd" "mkpasswd" || return 1
    check_and_install "fzf" "fzf" || return 1
    
    success "All dependency checks completed"
    return 0
}

# Wenn direkt ausgeführt
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_dependencies
fi