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
    
    local changes_detected=0
    local removed_users=""
    local added_users=""
    local users_without_password=""
    
    # Prüfe NUR auf neue Benutzer
    for user in $CONFIGURED_USERS; do
        # Prüfe ob der Benutzer überhaupt im System existiert
        if ! id "$user" >/dev/null 2>&1; then
            users_without_password="$users_without_password $user"
        fi
    done
    
    # Passwort-Management nur wenn wirklich nötig
    if [ ! -z "$users_without_password" ]; then
        log_warn "The following users have no password set:$users_without_password"
        
        for user in $users_without_password; do
            while true; do
                echo ""
                log_info "Setting password for user: $user"
                read -p "Do you want to set a password for $user now? [Y/n/s(skip)] " response
                
                case $response in
                    [Nn]* )
                        log_error "Aborting system rebuild."
                        exit 1
                        ;;
                    [Ss]* )
                        log_info "Skipping password for $user"
                        break
                        ;;
                    * )
                        # Erstelle Passwort-Verzeichnis im Build-Dir
                        mkdir -p "$PASSWORD_DIR/$user"
                        
                        # Setze Passwort
                        if passwd $user; then
                            # Speichere gehashtes Passwort im Build-Dir
                            getent shadow $user | cut -d: -f2 > "$PASSWORD_DIR/$user/.hashedPassword"
                            chmod 600 "$PASSWORD_DIR/$user/.hashedPassword"
                            log_success "Password set successfully for $user"
                            break
                        else
                            log_error "Failed to set password, please try again"
                        fi
                        ;;
                esac
            done
        done
    fi
    
    log_success "User configuration check passed"
    return 0
}

export -f check_user_passwords