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
    sed -i 's/systemType = ".*";/systemType = "desktop";/' "$SYSTEM_CONFIG_FILE"

    # Setze erstmal alle Desktop-Module auf false
    sed -i \
        -e '/gaming = {/,/};/s/streaming = .*;/streaming = false;/' \
        -e '/gaming = {/,/};/s/emulation = .*;/emulation = false;/' \
        -e '/development = {/,/};/s/game = .*;/game = false;/' \
        -e '/development = {/,/};/s/web = .*;/web = false;/' \
        "$SYSTEM_CONFIG_FILE"

    # Verarbeite die Module
    for module in "${@:1}"; do
        case "$module" in
            "Gaming-Streaming")
                sed -i '/gaming = {/,/};/s/streaming = .*;/streaming = true;/' "$SYSTEM_CONFIG_FILE"
                ;;
            "Gaming-Emulation")
                sed -i '/gaming = {/,/};/s/emulation = .*;/emulation = true;/' "$SYSTEM_CONFIG_FILE"
                ;;
            "Development-Game")
                sed -i '/development = {/,/};/s/game = .*;/game = true;/' "$SYSTEM_CONFIG_FILE"
                ;;
            "Development-Web")
                sed -i '/development = {/,/};/s/web = .*;/web = true;/' "$SYSTEM_CONFIG_FILE"
                ;;
        esac
    done

    log_success "Desktop profile modules updated"
}

process_selected_modules "$@"