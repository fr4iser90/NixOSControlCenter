#!/usr/bin/env bash

reset_database_state() {
    # Entferne database aus packageModules-Liste
    sed -i 's/ "database"//' "$SYSTEM_CONFIG_FILE"
    sed -i 's/"database" //' "$SYSTEM_CONFIG_FILE"
    # Falls Liste leer wird, setze auf []
    sed -i 's/packageModules = \[ "database" \];/packageModules = [];/' "$SYSTEM_CONFIG_FILE"
}

enable_database() {
    # Füge "database" zu packageModules-Liste hinzu
    # Prüfe ob packageModules-Liste existiert
    if ! grep -q "packageModules = \[" "$SYSTEM_CONFIG_FILE"; then
        # Füge packageModules-Liste hinzu
        sed -i '/systemType = ".*";/a\  packageModules = [];' "$SYSTEM_CONFIG_FILE"
    fi
    
    # Prüfe ob database bereits in der Liste ist
    if ! grep -q "\"database\"" "$SYSTEM_CONFIG_FILE"; then
        # Füge hinzu
        if grep -q "packageModules = \[\];" "$SYSTEM_CONFIG_FILE"; then
            sed -i 's/packageModules = \[\];/packageModules = [ "database" ];/' "$SYSTEM_CONFIG_FILE"
        else
            sed -i 's/];/ "database" ];/' "$SYSTEM_CONFIG_FILE"
        fi
    fi
}

export -f reset_database_state
export -f enable_database
