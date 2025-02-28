#!/usr/bin/env bash

# Required dependencies list
declare -A DEPENDENCIES=(
    ["pciutils"]="lspci"
    ["mkpasswd"]="mkpasswd"
    ["fzf"]="fzf"
)

# Interrupt Handler
on_interrupt() {
    log_error "\nScript interrupted. Aborting."
    exit 1
}

trap 'on_interrupt' SIGINT

check_and_install() {
    local package="$1"
    local command="$2"
    
    if ! command -v "$command" > /dev/null; then
        log_warning "$package is not installed (command: $command)"
        
        if ask_user "Do you want to proceed with installing $package?"; then
            log_info "Installing $package..."
            if ! nix-env -iA nixos."$package"; then
                log_error "$package installation failed!"
                return 1
            fi
            log_success "$package installed successfully"
        else
            log_error "$package is required but installation was declined"
            return 1
        fi
    else
        log_info "$package is already installed"
    fi
}

check_dependencies() {
    log_section "Checking Dependencies"
    
    for package in "${!DEPENDENCIES[@]}"; do
        check_and_install "$package" "${DEPENDENCIES[$package]}" || return 1
    done
    
    log_success "All dependency checks completed"
    return 0
}

remove_dependencies() {
    log_section "Removing Dependencies"
    
    for package in "${!DEPENDENCIES[@]}"; do
        if command -v "${DEPENDENCIES[$package]}" > /dev/null; then
            log_info "Removing $package..."
            if ! nix-env -e "$package"; then
                log_warning "$package removal failed"
            else
                log_success "$package removed successfully"
            fi
        fi
    done
}

# Export functions
export -f check_and_install
export -f check_dependencies
export -f remove_dependencies

# Check script execution
check_script_execution "LIB_DIR" "check_dependencies"