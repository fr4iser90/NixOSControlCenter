#!/usr/bin/env bash

# FZF base styling
FZF_DEFAULT_OPTS="
    --height=40% 
    --border=rounded 
    --preview-window=bottom:3:wrap
    --header-first
"

# Gemeinsame Funktionen für Modul-Auswahl
select_modules() {
    local title="$1"
    shift
    local -n modules="$1"  # Nameref auf das Modul-Array
    
    printf "%s\n" "${!modules[@]}" | fzf \
        --header="$title" \
        --preview="echo '${modules[{}]}'" \
        --multi \
        --prompt="Modules > "
}