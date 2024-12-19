#!/usr/bin/env bash

check_user_passwords() {
    log_section "Checking User Configuration"
    
    # Aktuelle System-Benutzer ermitteln
    local CURRENT_USERS=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $1 !~ /^nixbld/ && $1 !~ /^systemd-/ {print $1}')
    
    # Konfigurierte Benutzer aus system-config.nix extrahieren
    local CONFIGURED_USERS=$(awk '/users = {/,/};/ {if ($1 ~ /".*"/) print $1}' "$SYSTEM_CONFIG_FILE" | tr -d '"')
    
    # Das korrekte Password-Verzeichnis im Build-Dir
    local PASSWORD_DIR="build/secrets/passwords"
    
    log_info "Current system users: $CURRENT_USERS"
    log_info "Configured users: $CONFIGURED_USERS"
    
    # Erstelle Password-Dir wenn nicht existiert
    mkdir -p "$PASSWORD_DIR"
    
    # Sammle existierende Passwörter
    for user in $CURRENT_USERS; do
        if [ -f "$PASSWORD_DIR/$user/.hashedPassword" ]; then
            log_info "Found existing password for $user"
        else
            log_warn "No stored password found for $user"
            mkdir -p "$PASSWORD_DIR/$user"
            if getent shadow "$user" | cut -d: -f2 | grep -q '[^!*]'; then
                getent shadow "$user" | cut -d: -f2 > "$PASSWORD_DIR/$user/.hashedPassword"
                chmod 600 "$PASSWORD_DIR/$user/.hashedPassword"
                log_success "Stored existing password for $user"
            fi
        fi
    done
    
    log_success "Password collection complete"
    return 0
}

export -f check_user_passwords