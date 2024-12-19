#!/usr/bin/env bash

generate_preview() {
    local selection="$1"
    selection=$(echo "$selection" | sed 's/^⛔ //')
    local clean_selection=$(echo "$selection" | sed 's/^[ │├└─]*//g')
    
    if is_disabled "$clean_selection"; then
        echo -e "\033[31m❌ Diese Option ist nicht verfügbar mit der aktuellen Auswahl\033[0m"
        return
    fi

    local desc_type="${SETUP_TYPES[$clean_selection]:-CUSTOM SETUP}"
    local description="${SETUP_DESCRIPTIONS[$clean_selection]:-No description available}"
    local features="${SETUP_FEATURES[$clean_selection]:-}"

    local deps=($(activate_dependencies "$clean_selection"))
    local dep_list=""
    for dep in "${deps[@]}"; do
        if [[ "$dep" != "$clean_selection" ]]; then
            dep_list+="• $dep (required)\n"
        fi
    done

    cat << EOF
┌────────────────────────────────┐
│ SYSTEM TYPE: $desc_type
└────────────────────────────────┘

Description:
$description

Features:
$(echo "$features" | tr '|' '\n' | sed 's/^/• /')

Selected Module:
• $clean_selection

Required Dependencies:
$dep_list
EOF
}

export -f generate_preview