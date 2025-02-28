#!/usr/bin/env bash

# Declare arrays for options
echo "DEBUG in setup-mode.sh:"
declare -p SUB_OPTIONS

select_setup_mode() {
    # Clear previous selections
    selected=()
    
    # 1. Hauptauswahl
    local main_choice
    main_choice=$(printf "%s\n" "${MAIN_OPTIONS[@]}" | fzf \
        --header="Wähle die Hauptkategorie" \
        --bind 'space:accept' \
        --preview 'bash -c "generate_preview {}"' \
        --preview-window="right:50%:wrap" \
        --pointer="▶" \
        --marker="✓") || return 1

    [ -z "$main_choice" ] && return 1

    # Bei HomelabServer direkt zurückgeben
    if [[ "$main_choice" == "HomelabServer" ]]; then
        echo "Homelab"
        return 0
    fi
    
    # 2. Modulauswahl
    local module_choices=""
    if [[ -n "${SUB_OPTIONS["$main_choice"]:-}" ]]; then
        # Direkt die Optionen anzeigen
        module_choices=$(echo -n "${SUB_OPTIONS["$main_choice"]}" | tr '|' '\n' | fzf \
            --multi \
            --header="Wähle Module für $main_choice (Leertaste zum Auswählen, Enter zum Bestätigen)" \
            --bind 'tab:toggle,space:toggle' \
            --bind 'ctrl-a:toggle-all' \
            --preview 'generate_preview {}' \
            --preview-window="right:50%:wrap" \
            --pointer="▶" \
            --marker="✓")
        
        [ -z "$module_choices" ] && return 1
    fi

    # Baue finale Auswahl
    selected=("$main_choice")
    if [[ -n "$module_choices" ]]; then
        while IFS= read -r choice; do
            selected+=("$choice")
        done <<< "$module_choices"
    fi

    # Gib die Auswahl zurück
    echo "${selected[*]}"
    return 0
}

is_disabled() {
    local item="$1"
    
    # Basis-Module sind immer verfügbar
    [[ "$item" == "Desktop" || "$item" == "Server" || "$item" == "Custom Setup" || "$item" == "Homelab Server" ]] && return 1
    
    # If no selection yet, nothing is disabled
    [ ${#selected[@]} -eq 0 ] && return 1
    
    # Prüfe Server/Desktop Konflikte
    if [[ "$item" == "Server"* && " ${selected[*]} " =~ " Desktop " ]]; then
        return 0
    fi
    
    if [[ "$item" == "Desktop"* && " ${selected[*]} " =~ " Server " ]]; then
        return 0
    fi
    
    return 1
}

# Export functions and variables
export -f select_setup_mode
export -f is_disabled

# Nur ausführen wenn direkt aufgerufen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Ensure environment is initialized
    if [[ -z "${PROMPTS_DIR:-}" ]]; then
        echo "Error: Environment not properly initialized"
        exit 1
    fi
    
    select_setup_mode
fi