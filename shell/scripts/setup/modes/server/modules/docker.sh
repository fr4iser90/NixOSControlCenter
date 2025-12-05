#!/usr/bin/env bash

# Helper function to update packages-config.nix
update_packages_config() {
    local config_file="$(dirname "$SYSTEM_CONFIG_FILE")/configs/packages-config.nix"
    local package_modules="$1"
    
    # Create configs directory if it doesn't exist
    mkdir -p "$(dirname "$config_file")"
    
    # Read existing package modules if config exists
    local existing_modules=""
    if [ -f "$config_file" ]; then
        # Extract existing modules from the file
        existing_modules=$(grep -A 100 'packageModules = \[' "$config_file" | grep -o '"[^"]*"' | tr -d '"' | tr '\n' ' ' | sed 's/ $//')
    fi
    
    # Add or remove docker
    if [[ "$2" == "add" ]]; then
        if [[ "$existing_modules" != *"docker"* ]]; then
            if [[ -n "$existing_modules" ]]; then
                existing_modules="$existing_modules docker"
            else
                existing_modules="docker"
            fi
        fi
    elif [[ "$2" == "remove" ]]; then
        existing_modules=$(echo "$existing_modules" | sed 's/docker//g' | sed 's/  / /g' | sed 's/^ //' | sed 's/ $//')
    fi
    
    # Build modules list
    local modules_list=""
    if [[ -n "$existing_modules" ]]; then
        modules_list=$(echo "$existing_modules" | sed 's/^/    "/;s/$/"/' | sed 's/ /"\n    "/g')
    fi
    
    # Write complete packages-config.nix
    cat > "$config_file" <<EOF
{
  # Package-Modules
  packageModules = [
$modules_list
  ];
}
EOF
}

enable_docker() {
    # Add docker to packages-config.nix
    update_packages_config "" "add"
}

reset_docker_state() {
    # Remove docker from packages-config.nix
    update_packages_config "" "remove"
}

# Export functions
export -f enable_docker
export -f reset_docker_state
export -f update_packages_config
