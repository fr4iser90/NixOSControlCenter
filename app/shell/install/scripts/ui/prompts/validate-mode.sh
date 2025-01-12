
validate_selection() {
    local selections=("$@")
    
    # Check if selections are empty
    if [ ${#selections[@]} -eq 0 ]; then
        echo "No selections made."
        return 1
    fi

    # Example: Check for required base modules
    local required_modules=("Desktop" "Server")
    for required in "${required_modules[@]}"; do
        if [[ ! " ${selections[@]} " =~ " $required " ]]; then
            echo "Error: $required is required."
            return 1
        fi
    done

    # Example: Check for conflicting selections
    if [[ " ${selections[@]} " =~ " Gaming " && " ${selections[@]} " =~ " Server " ]]; then
        echo "Error: 'Gaming' and 'Server' cannot be selected together."
        return 1
    fi

    return 0
}