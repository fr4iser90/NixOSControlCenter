#!/usr/bin/env bash

# Einfachere Formatierung ohne Unicode-Symbole
format_option() {
    local option="$1"
    local is_selected="$2"
    
    # Nur Farben, keine Symbole
    if [[ "$option" == "Desktop" || "$option" == "Server" || "$option" == "HomelabServer" ]]; then
        echo -e "\033[1;36m$option\033[0m"  # Cyan für Hauptkategorien
    else
        echo -e "$option"  # Normal für alles andere
    fi
}

export -f format_option