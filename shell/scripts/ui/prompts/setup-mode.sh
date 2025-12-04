#!/usr/bin/env bash

# Declare arrays for options (ensure this is present if it was removed)
# echo "DEBUG in setup-mode.sh:"
# declare -p SUB_OPTIONS # This might be sourced from setup-options.sh now

# Helper: Build preset options array (for state machine)
build_preset_options_array() {
    local -n output_array="$1"
    output_array=()
    
    # Add System Presets
    for preset in "${SYSTEM_PRESETS[@]}"; do
        output_array+=("$preset")
    done
    
    # Add Device Presets if any exist
    if [[ ${#DEVICE_PRESETS[@]} -gt 0 ]]; then
        for preset in "${DEVICE_PRESETS[@]}"; do
            output_array+=("$preset")
        done
    fi
}

# Helper: Build feature options array (for state machine)
build_feature_options_array() {
    local -n output_array="$1"
    output_array=()
    
    for group in "${FEATURE_GROUPS[@]}"; do
        group_name="${group%%:*}"
        group_features="${group#*:}"
        output_array+=("$group_name")  # Add group header
        IFS='|' read -ra features <<< "$group_features"
        for feature in "${features[@]}"; do
            output_array+=("  $feature")  # Indented features
        done
    done
}

select_setup_mode() {
    local install_type_choice
    local final_selection=()

    # Get the directory of this script
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local PREVIEW_SCRIPT="$SCRIPT_DIR/formatting/preview.sh"

    # Step 1: Installation type selection (with back navigation)
    while true; do
        local result
        result=$(prompt_select "install_type" INSTALL_TYPE_OPTIONS \
            "Choose installation method" "$PREVIEW_SCRIPT")
        local exit_code=$?
        
        if [[ "$result" == "BACK" ]]; then
            # Already at first step, exit completely
            log_error "Installation type selection cancelled."
            return 1
        elif [[ "$result" == "EXIT" ]]; then
            log_error "Installation type selection cancelled."
            return 1
        else
            install_type_choice="$result"
            break
        fi
    done

    [ -z "$install_type_choice" ] && { log_error "No installation type selected."; return 1; }

    if [[ "$install_type_choice" == "📦 Presets" ]]; then
        # Build preset options array
        local PRESET_OPTIONS_ARRAY
        build_preset_options_array PRESET_OPTIONS_ARRAY
        
        # Step 2: Preset selection (with back navigation)
        while true; do
            local result
            result=$(prompt_select "preset" PRESET_OPTIONS_ARRAY \
                "Select preset" "$PREVIEW_SCRIPT")
            local exit_code=$?
            
            if [[ "$result" == "BACK" ]]; then
                # Go back to installation type selection
                pop_navigation  # Remove preset step
                continue  # Loop back to Step 1
            elif [[ "$result" == "EXIT" ]]; then
                log_error "Preset selection cancelled."
                return 1
            else
                local preset_choice="$result"
                
                # Validate it's a real preset
                if ! printf "%s\n" "${SYSTEM_PRESETS[@]}" "${DEVICE_PRESETS[@]}" | grep -q "^${preset_choice}$"; then
                    log_error "Invalid preset selected: $preset_choice"
                    continue  # Try again
                fi
                
                [ -z "$preset_choice" ] && { log_error "No preset selected."; continue; }
                final_selection=("$preset_choice")
                break
            fi
        done

    elif [[ "$install_type_choice" == "⚙️  Advanced Options" ]]; then
        # Step 2: Advanced Option selection (with back navigation)
        while true; do
            local result
            result=$(prompt_select "advanced_option" ADVANCED_OPTIONS \
                "Advanced Options" "$PREVIEW_SCRIPT")
            local exit_code=$?
            
            if [[ "$result" == "BACK" ]]; then
                # Go back to installation type selection
                pop_navigation  # Remove advanced option step
                continue  # Loop back to Step 1
            elif [[ "$result" == "EXIT" ]]; then
                log_error "Advanced option selection cancelled."
                return 1
            else
                local advanced_choice="$result"
                break
            fi
        done

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
            
            # Build profile options array
            local PROFILE_OPTIONS_ARRAY=()
            while IFS= read -r -d '' profile_file; do
                local profile_name=$(basename "$profile_file")
                [[ -n "$profile_name" ]] && PROFILE_OPTIONS_ARRAY+=("$profile_name")
            done < <(find "$profiles_dir" -type f -print0 2>/dev/null)
            
            # Step 3: Profile selection (with back navigation)
            while true; do
                local result
                local preview_cmd="cat $profiles_dir/{} 2>/dev/null || echo 'Preview not available'"
                result=$(prompt_select "profile" PROFILE_OPTIONS_ARRAY \
                    "Available Profiles (Select one to load)" \
                    "$preview_cmd")
                local exit_code=$?
                
                if [[ "$result" == "BACK" ]]; then
                    # Go back to advanced options
                    continue  # Loop back
                elif [[ "$result" == "EXIT" ]]; then
                    log_error "Profile selection cancelled."
                    return 1
                else
                    local selected_profile="$result"
                    break
                fi
            done

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

    elif [[ "$install_type_choice" == "🔧 Custom Install" ]]; then
        # Unified Feature Selection - keine Desktop/Server-Trennung mehr
        
        # Build feature options array
        local FEATURE_OPTIONS_ARRAY
        build_feature_options_array FEATURE_OPTIONS_ARRAY
        
        # Step 2: Feature selection (multi-select with back navigation)
        while true; do
            local result
            result=$(prompt_multi_select "features" FEATURE_OPTIONS_ARRAY \
                "Select features (Space to select, Enter to confirm)" \
                "$PREVIEW_SCRIPT")
            local exit_code=$?
            
            if [[ "$result" == "BACK" ]]; then
                # Go back to installation type selection
                pop_navigation  # Remove features step
                continue  # Loop back to Step 1
            elif [[ "$result" == "EXIT" ]]; then
                log_error "Feature selection cancelled."
                return 1
            else
                # Filtere nur Features (keine Gruppennamen)
                local selected_features=()
                while IFS= read -r choice; do
                    # Überspringe Gruppennamen (enthalten Emojis)
                    if [[ ! "$choice" =~ ^[🖥️📦🎮🐳💾] ]]; then
                        # Entferne führende Leerzeichen
                        choice=$(echo "$choice" | sed 's/^  //')
                        [[ -n "$choice" ]] && selected_features+=("$choice")
                    fi
                done <<< "$result"
                
                # Check if any features selected
                if [[ ${#selected_features[@]} -eq 0 ]]; then
                    log_error "No features selected."
                    continue  # Try again
                fi
                
                break
            fi
        done
        
        # Auto Conflict Resolution
        selected_features=($(resolve_conflicts "${selected_features[@]}"))
        
        # Auto Dependency Resolution
        selected_features=($(resolve_dependencies "${selected_features[@]}"))
        
        # System-Typ automatisch erkennen
        local system_type=$(detect_system_type "${selected_features[@]}")
        
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
export -f build_preset_options_array
export -f build_feature_options_array

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