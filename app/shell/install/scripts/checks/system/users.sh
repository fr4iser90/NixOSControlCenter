#!/usr/bin/env bash

log_section "Checking User Configuration"

get_user_info() {
    local current_user
    local current_shell
    local is_admin
    local user_block=""

    # Aktueller User
    current_user=$(whoami)
    current_shell=$(getent passwd "$current_user" | cut -d: -f7)
    
    # Admin-Status (wheel Gruppe)
    if groups "$current_user" | grep -q "wheel"; then
        is_admin="true"
    else
        is_admin="false"
    fi

    # Alle regulären User finden (UID >= 1000)
    while IFS=: read -r username _ uid _ _ home shell; do
        # Filtere System- und NixOS-Build-User aus
        if [ "$uid" -ge 1000 ] && [ "$uid" -le 60000 ] && \
           [[ ! "$username" =~ ^nixbld[0-9]+$ ]] && \
           [[ ! "$username" =~ ^nobody$ ]] && \
           [[ ! "$username" =~ ^nix$ ]]; then
            
            # Admin-Status für jeden User prüfen
            if groups "$username" 2>/dev/null | grep -q "wheel"; then
                user_role="admin"
            else
                user_role="user"
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
    };
"

            # Logging
            log_info "  User: ${CYAN}${username}${NC}"
            log_info "    Role: ${CYAN}${user_role}${NC}"
            log_info "    Shell: ${CYAN}${shell_name}${NC}"
        fi
    done < /etc/passwd

    # Entferne letztes Semikolon und Newline
    user_block=${user_block%;}

    # Export für weitere Verarbeitung
    export CURRENT_USER="$current_user"
    export CURRENT_SHELL="$current_shell"
    export IS_ADMIN="$is_admin"
    export ALL_USERS="$user_block"
}

# Ausführen
get_user_info