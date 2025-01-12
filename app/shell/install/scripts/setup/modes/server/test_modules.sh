#!/usr/bin/env bash

# Verhindern, dass Module mehrfach geladen werden
declare -g SERVER_MODULES_LOADED=${SERVER_MODULES_LOADED:-0}

if [[ "$SERVER_MODULES_LOADED" == "1" ]]; then
    return 0
fi

# Direkt am Anfang alle Module laden
log_debug "Loading server modules from: $MODES_SERVER_DIR/modules"
for module_file in "$MODES_SERVER_DIR/modules"/*.sh; do
    [[ -f "$module_file" ]] || continue
    log_debug "Loading module: $module_file"
    source "$module_file"
    
    # SOFORT nach dem Laden die Funktionen exportieren
    module_name=$(basename "$module_file" .sh)
    export -f "enable_${module_name}"
    export -f "reset_${module_name}_state"
done

# Markieren dass Module geladen wurden
SERVER_MODULES_LOADED=1

# Hilfsfunktionen
process_modules() {
    log_debug "Processing selected modules"
    local module
    for module in "$@"; do
        if [[ "$module" != "Server" ]]; then
            module="${module,,}"  # Alles klein machen
            enable_${module} || return 1
        fi
    done
    return 0
}

reset_module_states() {
    log_debug "Resetting module states"
    for module_file in "$MODES_SERVER_DIR/modules"/*.sh; do
        [[ -f "$module_file" ]] || continue
        local module_name=$(basename "$module_file" .sh)
        reset_${module_name}_state || return 1
    done
    return 0
}

# Diese Funktionen auch exportieren
export -f process_modules
export -f reset_module_states

# Nach dem Laden der Module
log_debug "Available functions after loading modules:"
declare -F