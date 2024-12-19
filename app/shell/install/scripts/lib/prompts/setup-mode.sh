#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/setup-descriptions.sh"
source "$(dirname "${BASH_SOURCE[0]}")/setup-rules.sh"
source "$(dirname "${BASH_SOURCE[0]}")/setup-options.sh"
source "$(dirname "${BASH_SOURCE[0]}")/setup-tree.sh"
source "$(dirname "${BASH_SOURCE[0]}")/setup-preview.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validate-mode.sh"
source "$(dirname "${BASH_SOURCE[0]}")/setup-formatting.sh"

declare -a selected=()

# Definiere die Unterkategorien pro Hauptkategorie
declare -A SUB_OPTIONS=(
    ["Desktop"]="None|Gaming|Gaming-Streaming|Gaming-Emulation|Development|Development-Web|Development-Game"
    ["Server"]="None|Docker|Database"
)

select_setup_mode() {
    # Clear previous selections
    selected=()
    
    # 1. Hauptauswahl
    local main_choice=$(printf "%s\n" "${MAIN_OPTIONS[@]}" | fzf \
        --header="Wähle die Hauptkategorie" \
        --bind 'space:accept' \
        --preview 'bash -c "generate_preview {}"' \
        --preview-window="right:50%:wrap" \
        --pointer="▶" \
        --marker="✓")

    [ -z "$main_choice" ] && return 1

    # Bei HomelabServer direkt zurückgeben
    if [[ "$main_choice" == "HomelabServer" ]]; then
        echo "Homelab"
        return 0
    fi
    
    # 2. Modulauswahl
    if [[ ${SUB_OPTIONS[$main_choice]} ]]; then
        local module_choices=$(echo ${SUB_OPTIONS[$main_choice]} | tr '|' '\n' | fzf \
            --multi \
            --header="Wähle Module für $main_choice (Leertaste zum Auswählen, Enter zum Bestätigen)" \
            --bind 'tab:toggle,space:toggle' \
            --bind 'ctrl-a:toggle-all' \
            --bind 'ctrl-n:change-preview(echo "None ausgewählt - andere Module deaktiviert")+toggle-all+toggle' \
            --preview 'generate_preview {}' \
            --preview-window="right:50%:wrap" \
            --pointer="▶" \
            --marker="✓")
        
        [ -z "$module_choices" ] && return 1
    fi

    # Baue finale Auswahl
    selected=("$main_choice")
    if [[ -n "$module_choices" ]]; then
        local has_none=false
        while IFS= read -r choice; do
            clean_choice=$(echo "$choice" | sed 's/^[ │├└─]*//g')
            if [[ "$clean_choice" = "None" ]]; then
                has_none=true
                break
            fi
            selected+=("$clean_choice")
        done <<< "$module_choices"

        if [[ "$has_none" = true ]]; then
            selected=("$main_choice" "None")
        fi
    fi

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

export -f is_disabled