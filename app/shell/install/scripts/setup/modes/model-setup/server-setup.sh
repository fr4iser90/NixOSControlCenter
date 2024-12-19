#!/usr/bin/env bash

process_selected_modules() {
    # Prüfe ob Parameter übergeben wurden
    if [ $# -eq 0 ]; then
        echo "Fehler: Keine Module übergeben"
        exit 1
    fi

    echo "Debug: Erhaltene Parameter: $@"
    
    local -a modules=("$@")
    echo "Debug: Array Inhalt: ${modules[@]}"
    
    # Hauptkategorie ist immer das erste Element
    local main_category="${modules[0]}"
    echo "Debug: Hauptkategorie: $main_category"
    
    # Alle weiteren Elemente sind die ausgewählten Module
    for module in "${modules[@]:1}"; do
        echo "Verarbeite Modul: $module"
        case "$module" in
            "Docker")
                echo "Konfiguriere Docker..."
                ;;
            "Database")
                echo "Konfiguriere Datenbank..."
                ;;
            "None")
                echo "Basis-Server-Konfiguration..."
                ;;
            *)
                echo "Unbekanntes Modul: $module"
                ;;
        esac
    done
}

# Verarbeite die übergebenen Module
process_selected_modules "$@"