#!/usr/bin/env bash

validate_selection() {
    local selections=("$@")
    
    # Check if selections are empty
    if [ ${#selections[@]} -eq 0 ]; then
        echo "No selections made."
        return 1
    fi

    # Check for feature conflicts
    # Docker conflicts
    if [[ " ${selections[@]} " =~ " docker " && " ${selections[@]} " =~ " podman " ]]; then
        echo "Error: 'docker' and 'podman' cannot be selected together."
        return 1
    fi

    return 0
}

export -f validate_selection
