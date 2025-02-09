#!/usr/bin/env bash

check_hosting() {
    log_section "Checking Hosting Configuration"
    
    local domain=""
    local email=""
    local virt_user=""

    # Check common config locations
    local config_files=(
        "/etc/nixos/configuration.nix"
        "/etc/nixos/system-config.nix"
        "$NIXOS_CONFIG_DIR/system-config.nix"
        "$SYSTEM_CONFIG_FILE"
    )

    # Try to find existing config values
    for config in "${config_files[@]}"; do
        if [[ -f "$config" ]]; then
            log_debug "Checking config: $config"
            
            # Extract values if they exist
            [[ -z "$domain" ]] && domain=$(grep -oP 'domain\s*=\s*"\K[^"]+' "$config" || true)
            [[ -z "$email" ]] && email=$(grep -oP 'email\s*=\s*"\K[^"]+' "$config" || true)
            [[ -z "$virt_user" ]] && virt_user=$(grep -oP 'virtUser\s*=\s*"\K[^"]+' "$config" || true)
        fi
    done

    # Fallback checks
    if [[ -z "$domain" ]] && [[ -f "/etc/hostname" ]]; then
        domain=$(grep -oP '[\w-]+\.[\w.]+$' /etc/hostname || true)
    fi

    if [[ -z "$virt_user" ]]; then
        if id docker &>/dev/null; then
            virt_user="docker"
        elif id virt &>/dev/null; then
            virt_user="virt"
        fi
    fi

    if [[ -z "$email" ]] && command -v git >/dev/null; then
        email=$(git config --global user.email || true)
    fi

    # Export für weitere Verarbeitung
    export HOST_DOMAIN="$domain"
    export HOST_EMAIL="$email"
    export VIRT_USER="$virt_user"

    # Logging
    [[ -n "$domain" ]] && log_info "  Domain: ${domain}"
    [[ -n "$email" ]] && log_info "  Email: ${email}"
    [[ -n "$virt_user" ]] && log_info "  Virt User: ${virt_user}"
    
    return 0
}

# Export functions
export -f check_hosting

# Check script execution
check_script_execution "SYSTEM_CONFIG_FILE" "check_hosting"