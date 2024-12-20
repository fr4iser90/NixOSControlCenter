#!/usr/bin/env bash

check_users() {
    log_section "Checking User Configuration"

    local current_user
    local current_shell
    local user_block=""

    # Aktueller User
    current_user=$(whoami)
    current_shell=$(getent passwd "$current_user" | cut -d: -f7)

    # Alle regulären User finden (UID >= 1000)
    while IFS=: read -r username _ uid _ _ home shell; do
        # Filtere System- und NixOS-Build-User aus
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
    };
"

            # Logging
            log_info "  User: ${username}"
            log_info "    Role: ${user_role}"
            log_info "    Shell: ${shell_name}"
        fi
    done < /etc/passwd

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