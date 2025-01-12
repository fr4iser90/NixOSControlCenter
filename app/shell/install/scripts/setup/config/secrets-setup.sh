#!/usr/bin/env bash

setup_password() {
    log_section "Setting Up Password"
    
    # Constants
    local output_dir="nixos/secrets/passwords"
    local output_file="$output_dir/.hashedLoginPassword"
    
    # Check for existing password
    if [[ -f "$output_file" ]]; then
        log_info "Using existing hashed password"
        cat "$output_file"
        return 0
    fi
    
    # Get and verify password
    local password hashed_password
    while true; do
        # Get password
        password=$(get_password) || {
            log_error "Password input cancelled"
            return 1
        }
        
        # Verify password
        if verify_password "$password"; then
            break
        fi
    done
    
    # Hash and save password
    save_hashed_password "$password" "$output_dir" "$output_file"
}

get_password() {
    local password
    while true; do
        read -sp "${BLUE}[?]${NC} Please enter a password: " password
        echo
        
        if [[ -n "$password" ]]; then
            echo "$password"
            return 0
        fi
        
        log_error "Password cannot be empty. Please try again."
    done
}

verify_password() {
    local password="$1"
    local password_confirm
    
    read -sp "${BLUE}[?]${NC} Please confirm the password: " password_confirm
    echo
    
    if [[ "$password" == "$password_confirm" ]]; then
        return 0
    fi
    
    log_error "Passwords do not match. Please try again."
    return 1
}

hash_password() {
    local password="$1"
    echo "$password" | mkpasswd -m sha-512 -s
}

save_hashed_password() {
    local password="$1"
    local output_dir="$2"
    local output_file="$3"
    
    # Create directory
    ensure_dir "$output_dir"
    
    # Hash and save
    local hashed_password
    hashed_password=$(hash_password "$password") || {
        log_error "Failed to hash password"
        return 1
    }
    
    printf "%s\n" "$hashed_password" > "$output_file" || {
        log_error "Failed to save hashed password"
        return 1
    }
    
    chmod 600 "$output_file" || {
        log_error "Failed to set permissions on password file"
        return 1
    }
    
    log_success "Password hashed and saved to $output_file"
}

# Export functions
export -f setup_password
export -f get_password
export -f verify_password
export -f hash_password
export -f save_hashed_password

# Check script execution
check_script_execution "LIB_DIR" "setup_password"
