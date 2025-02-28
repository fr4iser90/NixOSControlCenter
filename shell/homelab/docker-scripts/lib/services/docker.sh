#!/bin/bash

# Guard gegen mehrfaches Laden
if [ -n "${_DOCKER_SERVICE_LOADED+x}" ]; then
    return 0
fi
_DOCKER_SERVICE_LOADED=1

# ==============================================
# Docker Service Functions
# ==============================================

start_docker_container() {
    local container=$1
    local docker_dir=$(get_docker_dir "$container")

    if [ -z "$docker_dir" ]; then
        print_status "Invalid container: $container" "error"
        return 1
    fi

    print_status "Starting $container" "info"

    # Check for update-env.sh
    if [ -f "$docker_dir/update-env.sh" ]; then
        print_status "Running environment updates..." "info"
        (cd "$docker_dir" && bash update-env.sh)
    fi

    if [ -d "$docker_dir" ]; then
        (cd "$docker_dir" && docker compose up -d)
        print_status "Container started successfully" "success"
        return 0
    else
        print_status "Container directory not found" "error"
        return 1
    fi
}

restart_docker_container() {
    local container=$1
    local docker_dir=$(get_docker_dir "$container")

    if [ -z "$docker_dir" ]; then
        print_status "Invalid container: $container" "error"
        return 1
    fi

    if [ -d "$docker_dir" ]; then
        print_status "Restarting $container" "info"
        (cd "$docker_dir" && docker compose up -d --force-recreate)
        print_status "Container restarted successfully" "success"
        return 0
    else
        print_status "Container directory not found" "error"
        return 1
    fi
}