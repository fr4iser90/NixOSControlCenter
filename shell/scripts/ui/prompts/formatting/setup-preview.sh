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
    
    # Generate preview sections
    generate_header "$clean_selection"
    generate_description "$clean_selection"
    generate_features "$clean_selection"
    generate_dependencies "$clean_selection"
    
    return 0
}
export -f generate_preview

clean_selection_string() {
    echo "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/ /-/g' | tr '[:upper:]' '[:lower:]'
}
export -f clean_selection_string

generate_header() {
    local title="$1"
    echo -e "\\033[1;34m${title}\\033[0m" # Bold Blue
    echo "------------------------------------"
}
export -f generate_header

generate_description() {
    local selection="$1"
    echo # Empty line for spacing
    get_setup_description "$selection"
}
export -f generate_description

generate_features() {
    local selection="$1"
    
    echo # Empty line
    echo -e "\\033[1mType:\\033[0m ${SETUP_TYPES[$selection]:-N/A}"
    echo -e "\\033[1mFeatures:\\033[0m"
    local features_text=${SETUP_FEATURES[$selection]:-N/A}
    if [[ "$features_text" == "N/A" || -z "$features_text" ]]; then
        echo "  - No specific features listed."
    else
        echo "$features_text" | tr '|' '\n' | sed 's/^/  - /' # Convert | to newlines and indent
    fi
}
export -f generate_features

generate_dependencies() {
    local selection="$1"
    
    # Check for dependencies
    if [[ -n "${REQUIRES[$selection]:-}" ]]; then
        echo # Empty line
        echo -e "\\033[1mDependencies:\\033[0m"
        # Use activate_dependencies to get the full list
        local deps
        deps=$(activate_dependencies "$selection")
        for dep in $deps; do
            # Skip self-dependency in display if present
            [[ "$dep" == "$selection" ]] && continue
            local display_dep_name
            display_dep_name=$(get_display_name "$dep")
            echo "  - $display_dep_name"
        done
    else
        echo # Empty line
        echo -e "\\033[1mDependencies:\\033[0m None"
    fi
}
export -f generate_dependencies

# Check script execution
check_script_execution "CORE_DIR" "generate_preview"