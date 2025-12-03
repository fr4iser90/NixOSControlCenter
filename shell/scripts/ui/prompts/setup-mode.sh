#!/usr/bin/env bash

# Declare arrays for options (ensure this is present if it was removed)
# echo "DEBUG in setup-mode.sh:"
# declare -p SUB_OPTIONS # This might be sourced from setup-options.sh now

select_setup_mode() {
    local install_type_choice
    local final_selection=()

    # Get the directory of this script
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local PREVIEW_SCRIPT="$SCRIPT_DIR/formatting/preview.sh"

    # 1. Auswahl des Installationstyps
    install_type_choice=$(printf "%s\n" "${INSTALL_TYPE_OPTIONS[@]}" | fzf \
        --header="Choose installation method" \
        --bind 'space:accept' \
        --preview "$PREVIEW_SCRIPT {}" \
        --preview-window="right:50%:wrap" \
        --pointer="▶" \
        --marker="✓") || { log_error "Installation type selection cancelled."; return 1; }

    [ -z "$install_type_choice" ] && { log_error "No installation type selected."; return 1; }

    if [[ "$install_type_choice" == "Install a Predefined Profile" ]]; then
        # 2a. Auswahl eines vordefinierten Profils mit Unterteilung
        local profile_choice
        
        # Erstelle eine formatierte Liste mit Gruppen
        local profile_list=""
        profile_list+="━━━ Server Profiles ━━━\n"
        for profile in "${PREDEFINED_SERVER_PROFILES[@]}"; do
            profile_list+="$profile\n"
        done
        profile_list+="\n━━━ Desktop Profiles ━━━\n"
        for profile in "${PREDEFINED_DESKTOP_PROFILES[@]}"; do
            profile_list+="$profile\n"
        done
        
        profile_choice=$(printf "%b" "$profile_list" | fzf \
            --header="Select a Predefined Profile" \
            --bind 'space:accept' \
            --bind 'enter:accept' \
            --preview "$PREVIEW_SCRIPT {}" \
            --preview-window="right:50%:wrap" \
            --pointer="▶" \
            --marker="✓") || { log_error "Profile selection cancelled."; return 1; }

        # Entferne Trennlinien und Whitespace
        profile_choice=$(echo "$profile_choice" | sed 's/^━━━.*━━━$//' | sed '/^$/d' | head -1)
        
        [ -z "$profile_choice" ] && { log_error "No profile selected."; return 1; }
        final_selection=("$profile_choice")

    elif [[ "$install_type_choice" == "Configure a Custom Setup" ]]; then
        # 2b. Auswahl des Basis-Modus (Desktop/Server)
        local custom_base_choice
        custom_base_choice=$(printf "%s\n" "${CUSTOM_BASE_MODES[@]}" | fzf \
            --header="Choose the base for your custom setup" \
            --bind 'space:accept' \
            --preview "$PREVIEW_SCRIPT {}" \
            --preview-window="right:50%:wrap" \
            --pointer="▶" \
            --marker="✓") || { log_error "Custom base mode selection cancelled."; return 1; }

        [ -z "$custom_base_choice" ] && { log_error "No custom base mode selected."; return 1; }
        final_selection=("$custom_base_choice")

        # 3b. Modulauswahl für den Custom Base Mode
        local module_choices_string=""
        if [[ -n "${SUB_OPTIONS["$custom_base_choice"]:-}" ]]; then
            module_choices_string=$(echo -n "${SUB_OPTIONS["$custom_base_choice"]}" | tr '|' '\n' | fzf \
                --multi \
                --header="Select modules for $custom_base_choice (Space to select, Enter to confirm)" \
                --bind 'tab:toggle,space:toggle,ctrl-a:toggle-all' \
                --preview "$PREVIEW_SCRIPT {}" \
                --preview-window="right:50%:wrap" \
                --pointer="▶" \
                --marker="✓")
        fi

        if [[ -n "$module_choices_string" ]]; then
            while IFS= read -r choice; do
                [[ "$choice" != "None" && -n "$choice" ]] && final_selection+=("$choice")
            done <<< "$module_choices_string"
        fi
    else
        log_error "Invalid installation type: $install_type_choice"
        return 1
    fi

    echo "${final_selection[*]}"
    return 0
}

# Export functions and variables
export -f select_setup_mode

# Nur ausführen wenn direkt aufgerufen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Ensure environment is initialized (setup-options.sh should be sourced by caller)
    if [[ -z "${INSTALL_TYPE_OPTIONS[*]:-}" ]]; then
        echo "Error: Environment not properly initialized. Source setup-options.sh"
        # Minimal load for direct testing if possible:
        # current_dir=$(dirname "${BASH_SOURCE[0]}")
        # source "$current_dir/setup-options.sh"
        # if [[ -z "${INSTALL_TYPE_OPTIONS[*]:-}" ]]; then exit 1; fi
        exit 1
    fi
    
    # Mock generate_preview for direct testing if not available
    if ! command -v generate_preview &> /dev/null; then
        generate_preview() {
            echo "Preview for: $1"
            # Call actual is_disabled if you want to test its output here
            # if is_disabled "$1"; then
            #     echo "(This item would be considered disabled by the is_disabled function)"
            # fi
        }
        export -f generate_preview
    fi
    
    select_setup_mode
fi