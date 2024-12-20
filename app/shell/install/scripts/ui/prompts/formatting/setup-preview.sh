#!/usr/bin/env bash
set -euo pipefail

# Source core components
source "$CORE_DIR/imports.sh"

# Constants
declare -r PREVIEW_WIDTH=40

generate_preview() {
    local selection="$1"
    
    # Clean up selection string
    local clean_selection
    clean_selection=$(clean_selection_string "$selection") || return 1
    
    # Check if option is available
    if is_disabled "$clean_selection"; then
        log_error "This option is not available with the current selection"
        return 1
    fi
    
    # Generate preview sections
    local preview
    preview=$(
        generate_header "$clean_selection"
        generate_description "$clean_selection"
        generate_features "$clean_selection"
        generate_dependencies "$clean_selection"
    )
    
    echo "$preview"
    return 0
}

clean_selection_string() {
    local selection="$1"
    # Remove disabled marker and tree characters
    echo "$selection" | sed -e 's/^⛔ //' -e 's/^[ │├└─]*//'
}

generate_header() {
    local selection="$1"
    local desc_type="${SETUP_TYPES[$selection]:-CUSTOM SETUP}"
    
    cat << EOF
┌$("printf '%.0s─' $(seq 1 $PREVIEW_WIDTH))┐
│ SYSTEM TYPE: $desc_type$(printf '%.*s' $((PREVIEW_WIDTH - 14 - ${#desc_type})) " ")│
└$("printf '%.0s─' $(seq 1 $PREVIEW_WIDTH))┘

EOF
}

generate_description() {
    local selection="$1"
    local description="${SETUP_DESCRIPTIONS[$selection]:-No description available}"
    
    cat << EOF
Description:
$description

EOF
}

generate_features() {
    local selection="$1"
    local features="${SETUP_FEATURES[$selection]:-}"
    
    if [[ -n "$features" ]]; then
        echo "Features:"
        echo "$features" | tr '|' '\n' | sed 's/^/• /'
        echo
    fi
}

generate_dependencies() {
    local selection="$1"
    local deps
    
    # Get dependencies
    mapfile -t deps < <(activate_dependencies "$selection")
    
    echo "Selected Module:"
    echo "• $selection"
    echo
    
    if ((${#deps[@]} > 1)); then
        echo "Required Dependencies:"
        for dep in "${deps[@]}"; do
            if [[ "$dep" != "$selection" ]]; then
                echo "• $dep (required)"
            fi
        done
        echo
    fi
}

# Check script execution
check_script_execution "CORE_DIR" "generate_preview"