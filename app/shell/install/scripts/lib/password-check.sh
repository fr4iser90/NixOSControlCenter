#!/usr/bin/env bash

check_user_passwords() {
    log_section "Checking User Configuration"
    
    # Aktuelle System-Benutzer ermitteln
    local CURRENT_USERS=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $1 !~ /^nixbld/ && $1 !~ /^systemd-/ {print $1}')
    
    # Konfigurierte Benutzer aus system-config.nix extrahieren
    local CONFIGURED_USERS=$(grep -A 20 "users = {" "$SYSTEM_CONFIG_FILE" | grep -B 20 "};" | grep "=" | cut -d'"' -f2)
    
    # Mögliche Password-Verzeichnisse
    local PASSWORD_DIRS=(
        "/etc/nixos/secrets/passwords"
        "/etc/nixos/secrets"
        "/etc/nixos/password"
        "/etc/nixos"
    )
    
    log_info "Current system users: $CURRENT_USERS"
    log_info "Configured users: $CONFIGURED_USERS"
    
    local changes_detected=0
    local removed_users=""
    local added_users=""
    local users_without_password=""
    
    # Prüfe auf Änderungen und fehlende Passwörter
    for user in $CONFIGURED_USERS; do
        # Prüfe ob Benutzer neu ist
        if ! echo "$CURRENT_USERS" | grep -q "$user"; then
            added_users="$added_users $user"
            changes_detected=1
        fi
        
        # Suche nach Passwort-Datei in allen möglichen Verzeichnissen
        local password_found=0
        for dir in "${PASSWORD_DIRS[@]}"; do
            if [ -f "$dir/$user/.hashedPassword" ] && [ -s "$dir/$user/.hashedPassword" ]; then
                password_found=1
                break
            elif [ -f "$dir/$user/password" ] && [ -s "$dir/$user/password" ]; then
                password_found=1
                break
            elif [ -f "$dir/passwords/$user" ] && [ -s "$dir/passwords/$user" ]; then
                password_found=1
                break
            fi
        done
        
        if [ $password_found -eq 0 ]; then
            users_without_password="$users_without_password $user"
        fi
    done
    
    # Prüfe auf zu entfernende Benutzer
    for user in $CURRENT_USERS; do
        if ! echo "$CONFIGURED_USERS" | grep -q "$user"; then
            removed_users="$removed_users $user"
            changes_detected=1
        fi
    done
    
    # Zeige Änderungen an
    if [ $changes_detected -eq 1 ]; then
        log_warning "User configuration changes detected!"
        
        if [ ! -z "$removed_users" ]; then
            log_warning "Users to be removed:$removed_users"
        fi
        
        if [ ! -z "$added_users" ]; then
            log_warning "Users to be added:$added_users"
        fi
        
        log_warning "You will need to log out and log back in after applying these changes!"
        log_warning "Make sure to save all your work before proceeding!"
    fi
    
    # Passwort-Management nur wenn wirklich nötig
    if [ ! -z "$users_without_password" ]; then
        log_warning "The following users have no password set:$users_without_password"
        
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
                        # Erstelle Passwort-Verzeichnis
                        sudo mkdir -p "/etc/nixos/secrets/passwords/$user"
                        sudo chown $user:users "/etc/nixos/secrets/passwords/$user"
                        sudo chmod 700 "/etc/nixos/secrets/passwords/$user"
                        
                        # Setze Passwort
                        if sudo passwd $user; then
                            # Speichere gehashtes Passwort
                            sudo sh -c "getent shadow $user | cut -d: -f2 > /etc/nixos/secrets/passwords/$user/.hashedPassword"
                            sudo chown $user:users "/etc/nixos/secrets/passwords/$user/.hashedPassword"
                            sudo chmod 600 "/etc/nixos/secrets/passwords/$user/.hashedPassword"
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
    
    if [ $changes_detected -eq 1 ]; then
        read -p "Continue with system rebuild? [y/N] " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_error "Aborting system rebuild."
            exit 1
        fi
    fi
    
    log_success "User configuration check passed"
    return 0
}

export -f check_user_passwords