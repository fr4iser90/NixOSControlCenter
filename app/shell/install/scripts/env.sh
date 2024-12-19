#!/usr/bin/env bash

# Root-Verzeichnis des Scripts
export SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verzeichnis-Struktur
export LIB_DIR="${SCRIPT_ROOT}/lib"
export CHECKS_DIR="${SCRIPT_ROOT}/checks"
export SETUP_DIR="${SCRIPT_ROOT}/setup"

# Lade gemeinsame Bibliotheken
for lib in colors logging utils; do
    if [ -f "${LIB_DIR}/${lib}.sh" ]; then
        source "${LIB_DIR}/${lib}.sh"
    else
        echo "Error: Required library not found: ${lib}.sh"
        exit 1
    fi
done

# Prüfe ob die Struktur korrekt ist
check_structure() {
    local required_dirs=(
        "${LIB_DIR}"
        "${CHECKS_DIR}/hardware"
        "${CHECKS_DIR}/system"
        "${SETUP_DIR}/config"
        "${SETUP_DIR}/modes"
    )

    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo "Error: Required directory not found: $dir"
            exit 1
        fi
    done
}

# Initialisiere die Umgebung
init_env() {
    check_structure
    log_info "Environment initialized"
}

# Wenn direkt ausgeführt
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_env
fi 