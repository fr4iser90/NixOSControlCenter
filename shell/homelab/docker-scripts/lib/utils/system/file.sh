#!/bin/bash

# Guard gegen mehrfaches Laden
if [ -n "${_SYSTEM_FILE_LOADED+x}" ]; then
    return 0
fi
_SYSTEM_FILE_LOADED=1

# Update environment file
update_env_file() {
    local base_dir=$1
    local env_file=$2
    shift 2
    local new_values=("$@")

    if [ -f "$base_dir/$env_file" ]; then
        print_status "Updating $env_file" "info"
        for entry in "${new_values[@]}"; do
            local key="${entry%%:*}"
            local value="${entry#*:}"
            sed -i "s|^$key=.*|$key=$value|" "$base_dir/$env_file"
        done
        return 0
    else
        print_status "File $base_dir/$env_file does not exist" "error"
        return 1
    fi
}

update_conf_file() {
    local base_dir=$1
    local conf_file=$2
    shift 2
    local new_values=("$@")

    if [ -f "$base_dir/$conf_file" ]; then
        print_status "Updating $conf_file" "info"
        for entry in "${new_values[@]}"; do
            local key="${entry%%:*}"
            local value="${entry#*:}"
            sed -i "s|^$key:.*|$key: $value|" "$base_dir/$conf_file"
        done
        return 0
    else
        print_status "File $base_dir/$conf_file does not exist" "error"
        return 1
    fi
}

# Update docker-compose file
update_compose_file() {
    local base_dir=$1
    local compose_file=$2
    local uid=$3
    local gid=$4

    if [ -f "$base_dir/$compose_file" ]; then
        print_status "Updating $compose_file with UID=$uid and GID=$gid" "info"
        sed -i "s|PUID=[0-9]*|PUID=$uid|" "$base_dir/$compose_file"
        sed -i "s|PGID=[0-9]*|PGID=$gid|" "$base_dir/$compose_file"
        sed -i "s|PUID: '[0-9]*'|PUID: '$uid'|" "$base_dir/$compose_file"
        sed -i "s|PGID: '[0-9]*'|PGID: '$gid'|" "$base_dir/$compose_file"
        return 0
    else
        print_status "File $base_dir/$compose_file does not exist" "error"
        return 1
    fi
}

replace_placeholders_in_conf() {
    local base_dir=$1
    local conf_file=$2
    shift 2

    if [ ! -f "$base_dir/$conf_file" ]; then
        print_status "File $base_dir/$conf_file does not exist" "error"
        return 1
    fi

    # Debugging: Print all key-value pairs
    print_status "Replacing placeholders in $conf_file" "info"
    for entry in "$@"; do
        local key="${entry%%:*}"
        local value="${entry#*:}"
        print_status "Replacing \${$key} with $value" "debug"
        if [ -n "$value" ]; then
            sed -i "s|\${$key}|$value|g" "$base_dir/$conf_file"
        fi
    done

    return 0
}