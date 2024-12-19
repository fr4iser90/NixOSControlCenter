#!/usr/bin/env bash

process_selected_modules() {
    if [ $# -eq 0 ]; then
        echo "Fehler: Keine Module übergeben"
        exit 1
    fi

    # Backup erstellen
    if [ -f "$SYSTEM_CONFIG_FILE" ]; then
        backup_file "$SYSTEM_CONFIG_FILE"
    fi

    # Setze System Type
    sed -i 's/systemType = ".*";/systemType = "server";/' "$SYSTEM_CONFIG_FILE"

    # Setze erstmal alle Server-Module auf false
    sed -i \
        -e '/server = {/,/};/s/docker = .*;/docker = false;/' \
        -e '/server = {/,/};/s/web = .*;/web = false;/' \
        "$SYSTEM_CONFIG_FILE"

    # Verarbeite die Module
    for module in "${@:1}"; do
        case "$module" in
            "Docker")
                sed -i '/server = {/,/};/s/docker = .*;/docker = true;/' "$SYSTEM_CONFIG_FILE"
                ;;
            "Database")
                sed -i '/server = {/,/};/s/web = .*;/web = true;/' "$SYSTEM_CONFIG_FILE"
                ;;
        esac
    done

    log_success "Server profile modules updated"
}

process_selected_modules "$@"