#!/bin/bash

# Guard gegen mehrfaches Laden
if [ -n "${_SYSTEM_USER_LOADED+x}" ]; then
    return 0
fi
_SYSTEM_USER_LOADED=1

# Get user information
get_user_info() {
    # Get current user
    USER_NAME=${VIRT_USER:-$(whoami)}
    USER_UID=$(id -u "$USER_NAME")
    USER_GID=$(id -g "$USER_NAME")
    USER_HOME=${VIRT_HOME:-$(eval echo ~$USER_NAME)}

    # Export variables
    export USER_NAME
    export USER_UID
    export USER_GID
    export USER_HOME

    return 0
}