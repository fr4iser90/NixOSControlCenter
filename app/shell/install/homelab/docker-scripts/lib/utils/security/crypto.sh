#!/bin/bash

# Generate encryption key
generate_key() {
    local length="${1:-32}"
    nix-shell -p openssl --run "openssl rand -base64 $length"
}

# Encrypt string using openssl
encrypt_string() {
    local string="$1"
    local key="$2"
    
    if [ -z "$string" ] || [ -z "$key" ]; then
        echo -e "${ERROR} Both string and key are required"
        return 1
    fi
    
    echo -n "$string" | nix-shell -p openssl --run \
        "openssl enc -aes-256-cbc -a -salt -pass pass:$key"
}

# Decrypt string using openssl
decrypt_string() {
    local encrypted="$1"
    local key="$2"
    
    if [ -z "$encrypted" ] || [ -z "$key" ]; then
        echo -e "${ERROR} Both encrypted string and key are required"
        return 1
    fi
    
    echo -n "$encrypted" | nix-shell -p openssl --run \
        "openssl enc -aes-256-cbc -a -d -salt -pass pass:$key"
}

# Secure storage of credentials
secure_store() {
    local key="$1"
    local value="$2"
    local storage_file="${3:-$HOME/.secure_store}"
    
    # Generate storage key if not exists
    local storage_key
    if [ ! -f "$storage_file.key" ]; then
        storage_key=$(generate_key)
        echo "$storage_key" > "$storage_file.key"
        chmod 600 "$storage_file.key"
    else
        storage_key=$(cat "$storage_file.key")
    fi
    
    # Encrypt and store
    local encrypted=$(encrypt_string "$value" "$storage_key")
    echo "${key}=${encrypted}" >> "$storage_file"
    chmod 600 "$storage_file"
}

# Retrieve secure stored value
secure_retrieve() {
    local key="$1"
    local storage_file="${2:-$HOME/.secure_store}"
    
    if [ ! -f "$storage_file" ] || [ ! -f "$storage_file.key" ]; then
        echo -e "${ERROR} Secure storage not initialized"
        return 1
    fi
    
    local storage_key=$(cat "$storage_file.key")
    local encrypted=$(grep "^${key}=" "$storage_file" | cut -d'=' -f2-)
    
    if [ -n "$encrypted" ]; then
        decrypt_string "$encrypted" "$storage_key"
    else
        echo -e "${ERROR} Key not found: $key"
        return 1
    fi
}

# Füge diese Funktion hinzu:
generate_auto_password() {
    local length=16
    local chars='!@#$%^&*()_+-=[]{}|;:,.<>?'
    local password=$(nix-shell -p openssl --run "openssl rand -base64 32 | tr -dc 'a-zA-Z0-9${chars}' | head -c ${length}")
    echo "$password"
}

generate_auto_username() {
    local length=8
    local chars='a-zA-Z0-9'
    nix-shell -p openssl --run "openssl rand -base64 32 | tr -dc '${chars}' | head -c ${length}"
}