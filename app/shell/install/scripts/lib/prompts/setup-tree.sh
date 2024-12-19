#!/usr/bin/env bash

generate_tree() {
    local -a tree=()
    
    # Root Level
    tree+=("Desktop")
    tree+=("Server")
    tree+=("HomelabServer")
    tree+=("Custom Setup")
    
    # Generiere Tree basierend auf SETUP_DEPENDENCIES
    for item in "${!SETUP_DEPENDENCIES[@]}"; do
        local parent="${SETUP_DEPENDENCIES[$item]}"
        case "$parent" in
            "Desktop")
                [[ $item == "Gaming" || $item == "Development" ]] && tree+=("  ├─ $item") || tree+=("  └─ $item")
                ;;
            "Gaming")
                [[ $item == "Gaming-Streaming" ]] && tree+=("  │  ├─ $item") || tree+=("  │  └─ $item")
                ;;
            "Development")
                [[ $item == "Development-Web" ]] && tree+=("     ├─ $item") || tree+=("     └─ $item")
                ;;
            "Server")
                [[ $item == "Docker" ]] && tree+=("  ├─ $item") || tree+=("  └─ $item")
                ;;
        esac
    done
    
    printf '%s\n' "${tree[@]}"
}

export -f generate_tree