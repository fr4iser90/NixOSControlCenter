#!/usr/bin/env bash

# Constants
declare -r TEMP_FILE="/tmp/script_last_values"
declare -r CONFIG_DIR="build/setups"

collect_user_data() {
    log_section "Collecting User Data"
    
    # Load previous values if they exist
    if [[ -f "$TEMP_FILE" ]]; then
        source "$TEMP_FILE"
    fi
    
    # Collect user data
    log_info "Enter domain email etc if you want, or add it manually to modules if needed"
    
    local email="${EMAIL:-}"
    local domain="${DOMAIN:-}"
    
    # Prompt for values
    prompt_value "Please enter the certification resolver email" "email" "$email"
    prompt_value "Please enter the domain" "domain" "$domain"
    

    
    # Save values
    save_values "$domain" "$email"
    
    # Update configuration files
    update_nix_files "$domain" "$email"
    
    log_success "User data collection complete"
}

prompt_value() {
    local prompt_text="$1"
    local var_name="$2"
    local default_value="$3"
    local input_value
    
    read -p "${BLUE}[?]${NC} $prompt_text ${GRAY}($default_value)${NC}: " input_value
    input_value="${input_value:-$default_value}"
    
    # Update the caller's variable
    eval "$var_name=\"$input_value\""
}

save_values() {
    local domain="$1"
    local email="$2"

    
    # Export for other scripts
    export DOMAIN="$domain"
    export EMAIL="$email"

    
    # Save to temp file
    cat > "$TEMP_FILE" << EOF
DOMAIN="$domain"
EMAIL="$email"
EOF
}

update_nix_files() {
    local domain="$1"
    local email="$2"
    
    log_info "Updating configuration files..."
    
    shopt -s nullglob
    for nix_file in "$CONFIG_DIR"/*.nix; do
        if [[ -f "$nix_file" ]]; then
            if sed -i \
                -e "s/\(domain = \).*/\1\"$domain\";/" \
                -e "s/\(email = \).*/\1\"$email\";/" \
                "$nix_file"; then
                log_success "Updated $(basename "$nix_file")"
            else
                log_error "Failed to update $(basename "$nix_file")"
            fi
        fi
    done
}

# Export functions
export -f collect_user_data
export -f prompt_value
export -f save_values
export -f update_nix_files

# Check script execution
check_script_execution "CONFIG_DIR" "collect_user_data"
