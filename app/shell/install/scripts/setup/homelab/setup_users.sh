#!/usr/bin/env bash

setup_users() {
    log_section "User Setup"

    # Hauptbenutzer Setup
    log_info "Setting up main user"
    read -p "Enter main username: " main_user
    while [[ -z "$main_user" ]]; do
        log_error "Username cannot be empty"
        read -p "Enter main username: " main_user
    done

    # Virtualization user setup
    log_info "Setting up virtualization user"
    read -p "Enter virtualization username [docker]: " virt_user
    virt_user=${virt_user:-docker}

    # Email Konfiguration
    log_info "Setting up email configuration"
    read -p "Enter main email address: " email
    while [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; do
        log_error "Invalid email format"
        read -p "Enter main email address: " email
    done

    # Domain Konfiguration
    log_info "Setting up domain configuration"
    read -p "Enter domain (e.g., example.com): " domain
    while [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; do
        log_error "Invalid domain format"
        read -p "Enter domain: " domain
    done

    # SSL Cert Email
    log_info "Setting up SSL certificate email"
    read -p "Enter SSL certificate email [${email}]: " cert_email
    cert_email=${cert_email:-$email}

    # Update system-config.nix
    log_info "Updating system configuration"
    
    # Erstelle temporäre Datei für sed
    local temp_file=$(mktemp)
    cp "$SYSTEM_CONFIG_FILE" "$temp_file"

    # Ersetze den users-Block
    sed -i "/users = {/,/};/c\  users = {\n    \"${main_user}\" = {\n      role = \"admin\";\n      defaultShell = \"zsh\";\n      autoLogin = false;\n    };\n    \"${virt_user}\" = {\n      role = \"virtualization\";\n      defaultShell = \"zsh\";\n      autoLogin = false;\n    };\n  };" "$temp_file"

    # Füge Email/Domain Konfiguration hinzu
    if ! grep -q "email =" "$temp_file"; then
        sed -i "/^{/a\  email = \"${email}\";\n  domain = \"${domain}\";\n  certEmail = \"${cert_email}\";" "$temp_file"
    else
        sed -i "s/email = \".*\";/email = \"${email}\";/" "$temp_file"
        sed -i "s/domain = \".*\";/domain = \"${domain}\";/" "$temp_file"
        sed -i "s/certEmail = \".*\";/certEmail = \"${cert_email}\";/" "$temp_file"
    fi

    # Setze System-Typ und Profile-Module für Homelab
    sed -i "s/systemType = \".*\";/systemType = \"homelab\";/" "$temp_file"
    
    # Füge Homelab Profile-Module hinzu
    if ! grep -q "profileModules = {" "$temp_file"; then
        # Finde die letzte schließende Klammer
        last_line=$(grep -n "^}" "$temp_file" | tail -n1 | cut -d: -f1)
        
        # Füge Profile-Module VOR der letzten Klammer ein
        sed -i "${last_line}i\\
  profileModules = {\\
    homelab = {\\
      monitoring = true;\\
      media = true;\\
      storage = true;\\
      network = true;\\
    };\\
    server = {\\
      docker = true;\\
      web = true;\\
    };\\
    development = {\\
      web = false;\\
      game = false;\\
    };\\
    gaming = {\\
      streaming = false;\\
      emulation = false;\\
    };\\
  };" "$temp_file"
    fi

    # Überprüfe die Änderungen
    if diff "$SYSTEM_CONFIG_FILE" "$temp_file" >/dev/null; then
        log_error "Failed to update system configuration"
        rm "$temp_file"
        return 1
    fi

    # Wenn alles gut aussieht, verschiebe die temporäre Datei
    sudo mv "$temp_file" "$SYSTEM_CONFIG_FILE"
    
    log_success "User configuration complete"
    
    # Exportiere die Variablen für spätere Verwendung
    export MAIN_USER="$main_user"
    export VIRT_USER="$virt_user"
    export USER_EMAIL="$email"
    export USER_DOMAIN="$domain"
    export CERT_EMAIL="$cert_email"
}

export -f setup_users 