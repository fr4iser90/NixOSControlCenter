#!/usr/bin/env bash

enable_docker() {
    # Füge "docker-rootless" zu packageModules-Liste hinzu (Default)
    # Prüfe ob packageModules-Liste existiert
    if ! grep -q "packageModules = \[" "$SYSTEM_CONFIG_FILE"; then
        # Füge packageModules-Liste hinzu
        sed -i '/systemType = ".*";/a\  packageModules = [];' "$SYSTEM_CONFIG_FILE"
    fi
    
    # Prüfe ob docker-rootless bereits in der Liste ist
    if ! grep -q "\"docker-rootless\"" "$SYSTEM_CONFIG_FILE"; then
        # Füge hinzu
        if grep -q "packageModules = \[\];" "$SYSTEM_CONFIG_FILE"; then
            sed -i 's/packageModules = \[\];/packageModules = [ "docker-rootless" ];/' "$SYSTEM_CONFIG_FILE"
        else
            sed -i 's/];/ "docker-rootless" ];/' "$SYSTEM_CONFIG_FILE"
        fi
    fi
}

reset_docker_state() {
    # Entferne docker-rootless aus packageModules-Liste
    sed -i 's/ "docker-rootless"//' "$SYSTEM_CONFIG_FILE"
    sed -i 's/"docker-rootless" //' "$SYSTEM_CONFIG_FILE"
    # Falls Liste leer wird, setze auf []
    sed -i 's/packageModules = \[ "docker-rootless" \];/packageModules = [];/' "$SYSTEM_CONFIG_FILE"
}
