#!/usr/bin/env bash

check_users() {
    log_section "Checking User Configuration"

    local current_user
    local current_shell
    local user_block=""
    local needs_password_setup=false

    # Aktueller User
    current_user=$(whoami)
    current_shell=$(getent passwd "$current_user" | cut -d: -f7)

    # Alle regulären User finden (UID >= 1000)
    while IFS=: read -r username _ uid _ _ home shell; do
        if [ "$uid" -ge 1000 ] && [ "$uid" -le 60000 ] && \
           [[ ! "$username" =~ ^nixbld[0-9]+$ ]] && \
           [[ ! "$username" =~ ^nobody$ ]] && \
           [[ ! "$username" =~ ^nix$ ]]; then
            
            # Spezifische Rollen-Prüfung
            if groups "$username" 2>/dev/null | grep -q "wheel"; then
                if [[ "$username" == "admin" ]]; then
                    user_role="admin"
                else
                    user_role="restricted-admin"
                fi
                
                # Prüfe Passwort für Admin-User
                if ! getent shadow "$username" | grep -q "^$username:[^\*\!:]"; then
                    if [ ! -f "/etc/nixos/secrets/passwords/$username/.hashedPassword" ]; then
                        log_warning "Admin user '$username' has no password configured!"
                        needs_password_setup=true
                    fi
                fi
            elif groups "$username" 2>/dev/null | grep -q "docker"; then
                user_role="virtualization"
            else
                user_role="guest"
            fi

            # Shell-Pfad in Shell-Name umwandeln
            case "$shell" in
                *"/bash") shell_name="bash" ;;
                *"/zsh") shell_name="zsh" ;;
                *"/fish") shell_name="fish" ;;
                *) shell_name="bash" ;;
            esac

            # User-Block im Nix-Format erstellen
            user_block+="    \"$username\" = {
      role = \"$user_role\";
      defaultShell = \"$shell_name\";
      autoLogin = false;
"
            # Füge hashedPasswordFile hinzu, wenn es existiert
            if [ -f "/etc/nixos/secrets/passwords/$username/.hashedPassword" ]; then
                user_block+="      hashedPasswordFile = \"/etc/nixos/secrets/passwords/$username/.hashedPassword\";\n"
            fi

            user_block+="    };\n"

            # Logging
            log_info "  User: ${username}"
            log_info "    Role: ${user_role}"
            log_info "    Shell: ${shell_name}"
        fi
    done < /etc/passwd

    # Wenn Passwörter fehlen, biete Setup an
    if [ "$needs_password_setup" = true ]; then
        log_warning "Some admin users need password configuration!"
        read -p "Do you want to set up missing passwords now? [Y/n] " response
        if [[ ! "$response" =~ ^[Nn]$ ]]; then
            for username in $(getent group wheel | cut -d: -f4 | tr ',' ' '); do
                if ! getent shadow "$username" | grep -q "^$username:[^\*\!:]"; then
                    if [ ! -f "/etc/nixos/secrets/passwords/$username/.hashedPassword" ]; then
                        echo "Setting up password for $username..."
                        # Erstelle Verzeichnis
                        sudo mkdir -p "/etc/nixos/secrets/passwords/$username"
                        sudo chown "$username:users" "/etc/nixos/secrets/passwords/$username"
                        sudo chmod 700 "/etc/nixos/secrets/passwords/$username"
                        
                        # Setze Passwort
                        if passwd "$username"; then
                            sudo sh -c "getent shadow $username | cut -d: -f2 > /etc/nixos/secrets/passwords/$username/.hashedPassword"
                            sudo chown "$username:users" "/etc/nixos/secrets/passwords/$username/.hashedPassword"
                            sudo chmod 600 "/etc/nixos/secrets/passwords/$username/.hashedPassword"
                            log_success "Password set for $username"
                        else
                            log_error "Failed to set password for $username"
                            return 1
                        fi
                    fi
                fi
            done
        fi
    fi

    # Entferne letztes Semikolon und Newline
    user_block=${user_block%;}

    # Export für weitere Verarbeitung
    export CURRENT_USER="$current_user"
    export CURRENT_SHELL="$current_shell"
    export ALL_USERS="$user_block"
    
    return 0
}

# Export functions
export -f check_users