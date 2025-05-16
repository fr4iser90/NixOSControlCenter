# setup-rules.sh
#!/usr/bin/env bash

# Einfache Definition der Abhängigkeiten
declare -A REQUIRES=(
    ["Gaming"]="Desktop"
    ["Gaming-Streaming"]="Gaming"
    ["Gaming-Emulation"]="Gaming"
    ["Development"]="Desktop"
    ["Development-Web"]="Development"
    ["Development-Game"]="Development"
    ["Docker"]="Server"
    ["Database"]="Server"
)

# Einfache Funktion zum Aktivieren der Abhängigkeiten
activate_dependencies() {
    local module="$1"
    local deps=()
    local current="$module"
    
    # Füge das Hauptmodul hinzu
    deps+=("$current")
    
    # Rekursiv Abhängigkeiten hinzufügen
    while [[ -n "${REQUIRES[$current]:-}" ]]; do
        current="${REQUIRES[$current]}"
        deps+=("$current")
    done
    
    # Entferne Duplikate und gib das Ergebnis zurück
    echo "${deps[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '
}

# Exportiere die Funktion und das Array
export -f activate_dependencies
export REQUIRES

# Funktion zum Prüfen von Konflikten
check_conflicts() {
    local module="$1"
    
    # Beispiel für Konfliktprüfung
    if [[ "$module" == "Gaming" && -n "$(is_server_selected)" ]]; then
        return 1
    fi
    
    if [[ "$module" == "Server" && -n "$(is_desktop_selected)" ]]; then
        return 1
    fi
    
    return 0
}

export -f check_conflicts