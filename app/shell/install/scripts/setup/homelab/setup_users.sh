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

    # Passwort für beide Benutzer
    for user in "$main_user" "$virt_user"; do
        while true; do
            log_info "Setting password for $user"
            if sudo passwd "$user"; then
                break
            else
                log_error "Failed to set password for $user"
            fi
        done
    done

    # Erstelle secrets Verzeichnis
    local secrets_dir="/etc/nixos/secrets/passwords"
    sudo mkdir -p "$secrets_dir"

    # Speichere Passwort-Hashes
    for user in "$main_user" "$virt_user"; do
        local user_dir="$secrets_dir/$user"
        sudo mkdir -p "$user_dir"
        sudo sh -c "getent shadow $user | cut -d: -f2 > $user_dir/.hashedPassword"
        sudo chown -R "$user:users" "$user_dir"
        sudo chmod 700 "$user_dir"
        sudo chmod 600 "$user_dir/.hashedPassword"
    done

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
        cat >> "$temp_file" << EOF

  profileModules = {
    homelab = {
      monitoring = true;
      media = true;
      storage = true;
      network = true;
    };
    server = {
      docker = true;
      web = true;
    };
    development = {
      web = false;
      game = false;
    };
    gaming = {
      streaming = false;
      emulation = false;
    };
  };
EOF
    else
        # Aktualisiere existierende Profile-Module
        sed -i '/profileModules = {/,/};/c\  profileModules = {\n    homelab = {\n      monitoring = true;\n      media = true;\n      storage = true;\n      network = true;\n    };\n    server = {\n      docker = true;\n      web = true;\n    };\n    development = {\n      web = false;\n      game = false;\n    };\n    gaming = {\n      streaming = false;\n      emulation = false;\n    };\n  };' "$temp_file"
    fi

    # Überprüfe die Änderungen
    if diff "$SYSTEM_CONFIG_FILE" "$temp_file" >/dev/null; then
        log_error "Failed to update system configuration"
        rm "$temp_file"
        return 1
    fi

    # Wenn alles gut aussieht, verschiebe die temporäre Datei
    sudo mv "$temp_file" "$SYSTEM_CONFIG_FILE"
    
    log_success "User setup complete"
    
    # Exportiere die Variablen für spätere Verwendung
    export MAIN_USER="$main_user"
    export VIRT_USER="$virt_user"
    export USER_EMAIL="$email"
    export USER_DOMAIN="$domain"
    export CERT_EMAIL="$cert_email"
}

export -f setup_users 