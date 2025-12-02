# setup-rules.sh
#!/usr/bin/env bash

# Feature Dependencies (neue Struktur)
# Format: ["feature"]="dependency1 dependency2"
declare -A REQUIRES=(
    ["virt-manager"]="qemu-vm"  # virt-manager benötigt qemu-vm
)

# Feature Conflicts (neue Struktur)
# Format: ["feature"]="conflict1 conflict2"
declare -A CONFLICTS=(
    ["docker"]="docker-rootless podman"
    ["docker-rootless"]="docker podman"
    ["podman"]="docker docker-rootless"
)

# Einfache Funktion zum Aktivieren der Abhängigkeiten
activate_dependencies() {
    local feature="$1"
    local deps=()
    local current="$feature"
    
    # Füge das Haupt-Feature hinzu
    deps+=("$current")
    
    # Rekursiv Abhängigkeiten hinzufügen
    while [[ -n "${REQUIRES[$current]:-}" ]]; do
        local dep="${REQUIRES[$current]}"
        deps+=("$dep")
        current="$dep"
    done
    
    # Entferne Duplikate und gib das Ergebnis zurück
    echo "${deps[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '
}

# Funktion zum Prüfen von Konflikten
check_conflicts() {
    local feature="$1"
    local selected_features=("${@:2}")
    
    # Prüfe ob Feature mit anderen Features in Konflikt steht
    if [[ -n "${CONFLICTS[$feature]:-}" ]]; then
        local conflicts="${CONFLICTS[$feature]}"
        for conflict in $conflicts; do
            if [[ " ${selected_features[@]} " =~ " $conflict " ]]; then
                echo "Error: '$feature' conflicts with '$conflict'"
                return 1
            fi
        done
    fi
    
    return 0
}

# Exportiere die Funktionen und Arrays
export -f activate_dependencies
export -f check_conflicts
export REQUIRES
export CONFLICTS
