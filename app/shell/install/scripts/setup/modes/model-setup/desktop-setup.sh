#!/usr/bin/env bash

process_selected_modules() {
    # Prüfe ob Parameter übergeben wurden
    if [ $# -eq 0 ]; then
        echo "Fehler: Keine Module übergeben"
        exit 1
    fi

    
    local -a modules=("$@")
    
    
    # Hauptkategorie ist immer das erste Element
    local main_category="${modules[0]}"
    
    
    # Alle weiteren Elemente sind die ausgewählten Module
    for module in "${modules[@]:1}"; do
        echo "Verarbeite Modul: $module"
        case "$module" in
            "Gaming")
                echo "Konfiguriere Gaming-Setup..."
                ;;
            "Gaming-Streaming")
                echo "Konfiguriere Streaming-Setup..."
                ;;
            "Gaming-Emulation")
                echo "Konfiguriere Emulations-Setup..."
                ;;
            "Development")
                echo "Konfiguriere Development-Setup..."
                ;;
            "Development-Web")
                echo "Konfiguriere Web-Development..."
                ;;
            "Development-Game")
                echo "Konfiguriere Game-Development..."
                ;;
            "None")
                echo "Basis-Desktop-Konfiguration..."
                ;;
            *)
                echo "Unbekanntes Modul: $module"
                ;;
        esac
    done
}

# Verarbeite die übergebenen Module
process_selected_modules "$@"