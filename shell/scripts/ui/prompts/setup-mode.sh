#!/usr/bin/env bash

# Declare arrays for options (ensure this is present if it was removed)
# echo "DEBUG in setup-mode.sh:"
# declare -p SUB_OPTIONS # This might be sourced from setup-options.sh now

# Prefer GUI when a display is available (friends / non-terminal). Override with:
#   NCC_INSTALL_UI=gui|tui|auto   (default: auto)
#
# GUI helpers live in ui/gui/gui-lib.sh (sourced from imports or here as fallback).
if ! declare -F ncc_install_ui_prefer_gui >/dev/null 2>&1; then
    # shellcheck source=../gui/gui-lib.sh
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../gui" && pwd)/gui-lib.sh"
fi

select_setup_mode_gui() {
    local gui_wrapper
    if [[ -n "${UI_DIR:-}" ]]; then
        gui_wrapper="${UI_DIR}/gui/select-setup-mode-gui.sh"
    else
        local here
        here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        gui_wrapper="$(cd "$here/../gui" && pwd)/select-setup-mode-gui.sh"
    fi
    if [[ ! -x "$gui_wrapper" && -f "$gui_wrapper" ]]; then
        chmod +x "$gui_wrapper" 2>/dev/null || true
    fi
    if [[ ! -f "$gui_wrapper" ]]; then
        return 2
    fi
    ncc_gui_ensure_answers_file
    "$gui_wrapper"
}

select_setup_mode() {
    local install_type_choice
    local final_selection=()

    # Get the directory of this script
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local PREVIEW_SCRIPT="$SCRIPT_DIR/formatting/preview.sh"

    # --- GUI path (same stdout contract as fzf path below) ---
    if ncc_install_ui_prefer_gui; then
        ncc_gui_ensure_answers_file
        local gui_selection="" gui_rc=0
        set +e
        gui_selection="$(select_setup_mode_gui)"
        gui_rc=$?
        set -e
        if [[ $gui_rc -eq 0 && -n "$gui_selection" ]]; then
            echo "$gui_selection"
            return 0
        elif [[ $gui_rc -eq 1 ]]; then
            log_error "Installation cancelled."
            return 1
        else
            # 2 = GUI unavailable → fall back to fzf TUI
            log_info "GUI unavailable — falling back to terminal UI (fzf)."
            log_info "Force GUI: NCC_INSTALL_UI=gui   | force TUI: NCC_INSTALL_UI=tui"
        fi
    fi

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
        # Build preset list with prefixes (no headers, no emojis)
        local preset_list=""
        
        # System Presets mit Präfix
        for preset in "${SYSTEM_PRESETS[@]}"; do
            preset_list+="$(format_item_with_prefix "System" "$preset")\n"
        done
        
        # Device Presets mit Präfix
        if [[ ${#DEVICE_PRESETS[@]} -gt 0 ]]; then
            for preset in "${DEVICE_PRESETS[@]}"; do
                preset_list+="$(format_item_with_prefix "Device" "$preset")\n"
            done
        fi
        
        # Show presets with fzf
        local preset_choice
        preset_choice=$(printf "%b" "$preset_list" | fzf \
            --header="Select preset" \
            --bind 'space:accept' \
            --preview "$PREVIEW_SCRIPT {}" \
            --preview-window="right:50%:wrap" \
            --pointer="▶" \
            --marker="✓") || { log_error "Preset selection cancelled."; return 1; }
        
        # Remove prefix from selection
        preset_choice=$(remove_prefix "$preset_choice")
        
        # Validate it's a real preset
        if ! printf "%s\n" "${SYSTEM_PRESETS[@]}" "${DEVICE_PRESETS[@]}" | grep -q "^${preset_choice}$"; then
            log_error "Invalid preset selected: $preset_choice"
            return 1
        fi
        
        [ -z "$preset_choice" ] && { log_error "No preset selected."; return 1; }

        ncc_gui_ensure_answers_file 2>/dev/null || true

        # From Scratch → old custom path (type + DE + packages)
        if [[ "$preset_choice" == "From Scratch" ]]; then
            log_info "From Scratch: select system type"
            local system_type_choice
            system_type_choice=$(printf "%s\n" "Desktop" "Server" | fzf \
                --header="Select system type" \
                --bind 'space:accept' \
                --preview "$PREVIEW_SCRIPT {}" \
                --preview-window="right:50%:wrap" \
                --pointer="▶" \
                --marker="✓") || { log_error "System type selection cancelled."; return 1; }
            local system_type="${system_type_choice,,}"
            local desktop_env=""
            if [[ "$system_type" == "desktop" ]]; then
                local de_choice
                de_choice=$(printf "%s\n" "Plasma (KDE)" "GNOME" "XFCE" "None" | fzf \
                    --header="Select desktop environment" \
                    --bind 'space:accept' \
                    --preview "$PREVIEW_SCRIPT {}" \
                    --preview-window="right:50%:wrap" \
                    --pointer="▶" \
                    --marker="✓") || { log_error "Desktop environment selection cancelled."; return 1; }
                case "$de_choice" in
                    "Plasma (KDE)") desktop_env="plasma" ;;
                    "GNOME") desktop_env="gnome" ;;
                    "XFCE") desktop_env="xfce" ;;
                    "None") desktop_env="" ;;
                esac
            fi
            local selected_features
            selected_features=($(ncc_tui_select_packages "")) || return 1
            if declare -F ncc_gui_write_answer >/dev/null 2>&1; then
                ncc_gui_write_answer PACKAGE_MODULES "${selected_features[*]}"
            fi
            if [[ -n "$desktop_env" ]]; then
                final_selection=("$system_type" "$desktop_env" "${selected_features[@]}")
            else
                final_selection=("$system_type" "${selected_features[@]}")
            fi
        else
            # Preset + optional package extras (defaults pre-merged in helper)
            local defaults="${PRESET_DEFAULT_PACKAGES[$preset_choice]:-}"
            log_info "Package extras for $preset_choice (defaults: ${defaults:-none})"
            local selected_features
            selected_features=($(ncc_tui_select_packages "$defaults")) || return 1
            if declare -F ncc_gui_write_answer >/dev/null 2>&1; then
                ncc_gui_write_answer PACKAGE_MODULES "${selected_features[*]}"
            fi
            final_selection=("$preset_choice")
        fi

    elif [[ "$install_type_choice" == "⚙️ Advanced Options" ]]; then
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

    else
        log_error "Invalid installation type: $install_type_choice"
        log_info "Use Presets (incl. From Scratch) or Advanced Options."
        return 1
    fi

    echo "${final_selection[*]}"
    return 0
}

# Multi-select package modules. $1 = space-separated defaults (always included + shown in header).
ncc_tui_select_packages() {
    local defaults_str="${1:-}"
    local -a defaults=()
    read -ra defaults <<< "$defaults_str"

    local feature_list=""
    local group group_name group_features clean_group_name feature
    for group in "${FEATURE_GROUPS[@]}"; do
        group_name="${group%%:*}"
        group_features="${group#*:}"
        [[ "$group_name" == "Desktop Environment" ]] && continue
        clean_group_name=$(echo "$group_name" | sed 's/^[🖥️📦🎮🐳💾] *//')
        IFS='|' read -ra features <<< "$group_features"
        for feature in "${features[@]}"; do
            feature_list+="$(format_item_with_prefix "$clean_group_name" "$feature")\n"
        done
    done

    local header="Packages: select full set (Enter with none = keep defaults: ${defaults_str:-none})"
    local feature_choices_string=""
    feature_choices_string=$(printf "%b" "$feature_list" | fzf \
        --multi \
        --header="$header" \
        --bind 'tab:toggle,space:toggle,ctrl-a:toggle-all' \
        --pointer="▶" \
        --marker="✓") || { log_error "Package selection cancelled."; return 1; }

    local selected_features=()
    local choice clean_choice
    while IFS= read -r choice; do
        clean_choice=$(remove_prefix "$choice")
        [[ -n "$clean_choice" ]] && selected_features+=("$clean_choice")
    done <<< "$feature_choices_string"

    # Empty selection → keep preset defaults
    if [[ ${#selected_features[@]} -eq 0 ]]; then
        selected_features=("${defaults[@]}")
    fi

    selected_features=($(resolve_conflicts "${selected_features[@]}"))
    selected_features=($(resolve_dependencies "${selected_features[@]}"))
    printf '%s\n' "${selected_features[@]}"
}

# System-Typ automatisch erkennen
detect_system_type() {
    local features=("$@")
    local system_type=""
    
    # Desktop Environment gewählt → Desktop
    for feature in "${features[@]}"; do
        if [[ "$feature" =~ ^(plasma|gnome|xfce)$ ]]; then
            system_type="desktop"
            break
        fi
    done
    
    # Server-Features (ohne Desktop-Env) → Server
    if [[ -z "$system_type" ]]; then
        for feature in "${features[@]}"; do
            if [[ "$feature" =~ ^(database|web-server|mail-server|docker|podman)$ ]]; then
                system_type="server"
                break
            fi
        done
    fi
    
    # Fallback: Wenn nichts erkannt → desktop (Standard)
    if [[ -z "$system_type" ]]; then
        system_type="desktop"
    fi
    
    echo "$system_type"
}

# Conflict Resolution
resolve_conflicts() {
    local features=("$@")
    local resolved=()
    
    for feature in "${features[@]}"; do
        local conflicts="${FEATURE_CONFLICTS[$feature]:-}"
        if [[ -n "$conflicts" ]]; then
            IFS='|' read -ra conflict_list <<< "$conflicts"
            local has_conflict=false
            for conflict in "${conflict_list[@]}"; do
                if [[ " ${features[*]} " =~ " $conflict " ]]; then
                    has_conflict=true
                    break
                fi
            done
            if [[ "$has_conflict" == "false" ]]; then
                resolved+=("$feature")
            fi
        else
            resolved+=("$feature")
        fi
    done
    
    printf '%s\n' "${resolved[@]}"
}

# Dependency Resolution
resolve_dependencies() {
    local features=("$@")
    local resolved=("${features[@]}")
    
    for feature in "${features[@]}"; do
        local deps="${FEATURE_DEPENDENCIES[$feature]:-}"
        if [[ -n "$deps" ]]; then
            IFS='|' read -ra dep_list <<< "$deps"
            for dep in "${dep_list[@]}"; do
                if [[ ! " ${resolved[*]} " =~ " $dep " ]]; then
                    resolved+=("$dep")
                fi
            done
        fi
    done
    
    printf '%s\n' "${resolved[@]}"
}

# Export functions and variables
export -f select_setup_mode_gui
export -f select_setup_mode
export -f ncc_tui_select_packages
export -f detect_system_type
export -f resolve_conflicts
export -f resolve_dependencies

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