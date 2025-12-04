#!/usr/bin/env bash

# Format item with prefix
format_item_with_prefix() {
    local category="$1"  # "System", "Device", "Desktop Environment", etc.
    local item="$2"      # "Desktop", "Server", "plasma", etc.
    
    echo "[$category] $item"
}

# Build formatted list from array
build_formatted_list() {
    local category="$1"
    shift
    local items=("$@")
    
    local formatted_list=""
    for item in "${items[@]}"; do
        formatted_list+="$(format_item_with_prefix "$category" "$item")\n"
    done
    
    printf "%b" "$formatted_list"
}

# Remove prefix from selection
remove_prefix() {
    local selection="$1"
    # Remove [Category] prefix
    echo "$selection" | sed 's/^\[.*\] //'
}

# Extract category from selection (for validation)
extract_category() {
    local selection="$1"
    # Extract [Category] from selection
    echo "$selection" | sed -n 's/^\[\(.*\)\].*/\1/p'
}

export -f format_item_with_prefix
export -f build_formatted_list
export -f remove_prefix
export -f extract_category

