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
        final_selection=("$preset_choice")

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

    elif [[ "$install_type_choice" == "🔧 Custom Setup" ]]; then
        # STEP 1: System Type Selection
        log_info "Step 1/3: Select system type"
        local system_type_choice
        system_type_choice=$(printf "%s\n" "Desktop" "Server" | fzf \
            --header="Select system type" \
            --bind 'space:accept' \
            --preview "$PREVIEW_SCRIPT {}" \
            --preview-window="right:50%:wrap" \
            --pointer="▶" \
            --marker="✓") || { log_error "System type selection cancelled."; return 1; }
        
        # Convert to lowercase
        local system_type="${system_type_choice,,}"
        log_info "Selected system type: $system_type"
        
        # STEP 2: Desktop Environment Selection (nur bei Desktop)
        local desktop_env=""
        if [[ "$system_type" == "desktop" ]]; then
            log_info "Step 2/3: Select desktop environment"
            local de_choice
            de_choice=$(printf "%s\n" "Plasma (KDE)" "GNOME" "XFCE" "None" | fzf \
                --header="Select desktop environment" \
                --bind 'space:accept' \
                --preview "$PREVIEW_SCRIPT {}" \
                --preview-window="right:50%:wrap" \
                --pointer="▶" \
                --marker="✓") || { log_error "Desktop environment selection cancelled."; return 1; }
            
            # Convert to internal name
            case "$de_choice" in
                "Plasma (KDE)") desktop_env="plasma" ;;
                "GNOME") desktop_env="gnome" ;;
                "XFCE") desktop_env="xfce" ;;
                "None") desktop_env="" ;;
            esac
            log_info "Selected desktop environment: ${desktop_env:-None}"
        fi
        
        # STEP 3: Feature Selection (OHNE Desktop Environment)
        log_info "Step ${desktop_env:+3/3:}${desktop_env:-2/2:} Select features"
        local feature_list=""
        for group in "${FEATURE_GROUPS[@]}"; do
            group_name="${group%%:*}"
            group_features="${group#*:}"
            
            # Skip Desktop Environment group (bereits in Schritt 2 gewählt)
            if [[ "$group_name" == "Desktop Environment" ]]; then
                continue
            fi
            
            # Emoji entfernen aus group_name (falls noch vorhanden)
            clean_group_name=$(echo "$group_name" | sed 's/^[🖥️📦🎮🐳💾] *//')
            
            IFS='|' read -ra features <<< "$group_features"
            for feature in "${features[@]}"; do
                feature_list+="$(format_item_with_prefix "$clean_group_name" "$feature")\n"
            done
        done
        
        # Feature-Auswahl mit fzf
        local feature_choices_string=""
        feature_choices_string=$(printf "%b" "$feature_list" | fzf \
            --multi \
            --header="Select features (Space to select, Enter to confirm)" \
            --bind 'tab:toggle,space:toggle,ctrl-a:toggle-all' \
            --preview "$PREVIEW_SCRIPT {}" \
            --preview-window="right:50%:wrap" \
            --pointer="▶" \
            --marker="✓") || { log_error "Feature selection cancelled."; return 1; }

        # Filtere Features und entferne Präfixe
        local selected_features=()
        while IFS= read -r choice; do
            # Präfix entfernen
            clean_choice=$(remove_prefix "$choice")
            [[ -n "$clean_choice" ]] && selected_features+=("$clean_choice")
        done <<< "$feature_choices_string"
        
        # Auto Conflict Resolution (nur für Containerization)
        selected_features=($(resolve_conflicts "${selected_features[@]}"))
        
        # Auto Dependency Resolution
        selected_features=($(resolve_dependencies "${selected_features[@]}"))
        
        # Desktop Environment hinzufügen (wenn gewählt)
        if [[ -n "$desktop_env" ]]; then
            selected_features=("$desktop_env" "${selected_features[@]}")
        fi
        
        # Finale Auswahl: System-Typ + Features
        final_selection=("$system_type" "${selected_features[@]}")
    else
        log_error "Invalid installation type: $install_type_choice"
        return 1
    fi

    echo "${final_selection[*]}"
    return 0
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
            if [[ "$feature" =~ ^(database|web-server|mail-server|docker|docker-rootless|podman)$ ]]; then
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
export -f select_setup_mode
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