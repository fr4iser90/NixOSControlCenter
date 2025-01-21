#!/bin/bash

# Define root and directory paths
rescue_kit_root_dir="$(dirname "$(realpath "$0")")"

# Source configuration after paths are defined
modules_dir="$rescue_kit_root_dir/modules"
utils_dir="$rescue_kit_root_dir/utils"

# Source UI components
source "$utils_dir/ui/base.sh"
source "$utils_dir/ui/display.sh"
source "$utils_dir/ui/menus.sh"
source "$utils_dir/ui/prompts.sh"

# Track imported files
declare -A IMPORTED_FILES=()

# Dynamically source all modules with error checking
import_modules() {
    echo "Importing modules from $modules_dir..."
    
    # Import main modules
    for module in "$modules_dir"/*.sh; do
        if [[ -f "$module" ]]; then
            if source "$module" 2>/dev/null; then
                IMPORTED_FILES["$module"]=1
                echo "  ✓ $(basename "$module")"
            else
                echo "  ✗ $(basename "$module") (failed)"
                return 1
            fi
        fi
    done

    return 0
}

# Source utility scripts
import_utils() {
    echo "Importing utilities from $utils_dir..."
    for util in "$utils_dir"/*.sh; do
        if [[ -f "$util" ]]; then
            source "$util"
        fi
    done

    # Import UI utilities
    local ui_dir="$utils_dir/ui"
    if [[ -d "$ui_dir" ]]; then
        for ui_script in "$ui_dir"/*.sh; do
            if [[ -f "$ui_script" ]]; then
                source "$ui_script"
            fi
        done
    fi
}

# Export functions for use in other scripts
export -f import_modules
export -f import_utils
