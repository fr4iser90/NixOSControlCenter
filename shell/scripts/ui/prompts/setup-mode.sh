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

    if [[ "$install_type_choice" == "📦 Presets" ]]; then
        # 2a. Preset-Typ auswählen
        local preset_type_choice
        preset_type_choice=$(printf "%s\n" "🖥️  System Presets" "🤖 Device Presets" | fzf \
            --header="Select preset category" \
            --bind 'space:accept' \
            --preview "$PREVIEW_SCRIPT {}" \
            --preview-window="right:50%:wrap" \
            --pointer="▶" \
            --marker="✓") || { log_error "Preset type selection cancelled."; return 1; }

        if [[ "$preset_type_choice" == "🖥️  System Presets" ]]; then
            # System Presets auswählen
            local preset_choice
            preset_choice=$(printf "%s\n" "${SYSTEM_PRESETS[@]}" | fzf \
                --header="Select system preset" \
                --bind 'space:accept' \
                --preview "$PREVIEW_SCRIPT {}" \
                --preview-window="right:50%:wrap" \
                --pointer="▶" \
                --marker="✓") || { log_error "Preset selection cancelled."; return 1; }
            
            [ -z "$preset_choice" ] && { log_error "No preset selected."; return 1; }
            final_selection=("$preset_choice")
            
        elif [[ "$preset_type_choice" == "🤖 Device Presets" ]]; then
            # Device Presets auswählen
            local preset_choice
            preset_choice=$(printf "%s\n" "${DEVICE_PRESETS[@]}" | fzf \
                --header="Select device preset" \
                --bind 'space:accept' \
                --preview "$PREVIEW_SCRIPT {}" \
                --preview-window="right:50%:wrap" \
                --pointer="▶" \
                --marker="✓") || { log_error "Preset selection cancelled."; return 1; }
            
            [ -z "$preset_choice" ] && { log_error "No preset selected."; return 1; }
            final_selection=("$preset_choice")
        fi

    elif [[ "$install_type_choice" == "⚙️  Advanced Options" ]]; then
        # 2b. Advanced Option auswählen
        local advanced_choice
        advanced_choice=$(printf "%s\n" "${ADVANCED_OPTIONS[@]}" | fzf \
            --header="Advanced Options" \
            --bind 'space:accept' \
            --preview "$PREVIEW_SCRIPT {}" \
            --preview-window="right:50%:wrap" \
            --pointer="▶" \
            --marker="✓") || { log_error "Advanced option selection cancelled."; return 1; }

        [ -z "$advanced_choice" ] && { log_error "No advanced option selected."; return 1; }
        
        if [[ "$advanced_choice" == "📁 Load Profile from File" ]]; then
            # Prompt für Dateipfad
            local profile_path
            echo ""
            log_info "Enter path to profile file:"
            echo "  Examples:"
            echo "  • profiles/fr4iser-home"
            echo "  • /absolute/path/to/profile.nix"
            echo "  • ~/my-config.nix"
            echo ""
            read -p "Profile path: " profile_path
            
            if [[ -z "$profile_path" ]]; then
                log_error "No profile path provided"
                return 1
            fi
            
            # Resolve path (handle relative paths)
            if [[ ! "$profile_path" =~ ^/ ]]; then
                # Relative path - assume it's in profiles directory
                if [[ "$profile_path" != profiles/* ]]; then
                    profile_path="$SETUP_DIR/modes/profiles/$profile_path"
                else
                    profile_path="$SETUP_DIR/modes/$profile_path"
                fi
            fi
            
            if [[ ! -f "$profile_path" ]]; then
                log_error "Profile file not found: $profile_path"
                return 1
            fi
            
            final_selection=("LOAD_PROFILE:$profile_path")
            
        elif [[ "$advanced_choice" == "📋 Show Available Profiles" ]]; then
            # Liste alle Profile im profiles/ Verzeichnis
            local profiles_dir="$SETUP_DIR/modes/profiles"
            if [[ ! -d "$profiles_dir" ]]; then
                log_error "Profiles directory not found: $profiles_dir"
                return 1
            fi
            
            local profile_list=""
            while IFS= read -r -d '' profile_file; do
                local profile_name=$(basename "$profile_file")
                if [[ -n "$profile_name" ]]; then
                    profile_list+="$profile_name\n"
                fi
            done < <(find "$profiles_dir" -type f -print0 2>/dev/null)
            
            if [[ -z "$profile_list" ]]; then
                log_warn "No profiles found in $profiles_dir"
                return 1
            fi
            
            local selected_profile
            selected_profile=$(printf "%b" "$profile_list" | fzf \
                --header="Available Profiles (Select one to load)" \
                --bind 'space:accept' \
                --preview "cat $profiles_dir/{} 2>/dev/null || echo 'Preview not available'" \
            --preview-window="right:50%:wrap" \
            --pointer="▶" \
            --marker="✓") || { log_error "Profile selection cancelled."; return 1; }

            if [[ -n "$selected_profile" ]]; then
                final_selection=("LOAD_PROFILE:$profiles_dir/$selected_profile")
            else
                return 1
            fi
            
        elif [[ "$advanced_choice" == "🔄 Import from Existing Config" ]]; then
            # Import from existing system-config.nix
            local existing_config="$SYSTEM_CONFIG_FILE"
            if [[ ! -f "$existing_config" ]]; then
                log_error "No existing configuration found at: $existing_config"
                log_info "Create a configuration first using Presets or Custom Setup"
                return 1
            fi
            
            log_info "Importing from existing configuration: $existing_config"
            final_selection=("IMPORT_CONFIG:$existing_config")
        fi

    elif [[ "$install_type_choice" == "🔧 Custom Setup" ]]; then
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