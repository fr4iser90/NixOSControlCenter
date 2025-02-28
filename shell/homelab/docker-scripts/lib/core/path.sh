#!/bin/bash
if [ -n "${_PATH_LOADED+x}" ]; then
    return 0
fi
_PATH_LOADED=1

# Base installation paths
BASE_DIR="${HOME}"
DOCKER_BASE_DIR="${BASE_DIR}/docker"         # Für Container
DOCKER_LIB_DIR="${DOCKER_SCRIPTS_DIR}/lib"   # Für Libraries

# Export für andere Scripts
export DOCKER_BASE_DIR
export DOCKER_LIB_DIR

# Path helper functions
get_docker_dir() {
    local container=$1
    local category
    
    if [ -z "${MANAGEMENT_CATEGORIES[*]}" ]; then
        print_status "MANAGEMENT_CATEGORIES not defined" "error"
        return 1
    fi
    
    category=$(get_container_category "$container")
    if [ $? -eq 0 ]; then
        echo "$DOCKER_BASE_DIR/$category/$container"
        return 0
    fi
    
    print_status "Container $container not found" "error"
    return 1
}

get_lib_file() {
    local file=$1
    echo "$DOCKER_LIB_DIR/$file"
}

get_script_file() {
    local file=$1
    echo "$DOCKER_SCRIPTS_DIR/$file"
}