#!/bin/bash

# Guard gegen mehrfaches Laden
if [ -n "${_SCRIPT_HEADER_LOADED+x}" ]; then
    return 0
fi
_SCRIPT_HEADER_LOADED=1

# Verify imports
if [ ! -f "${DOCKER_SCRIPTS_DIR}/lib/core/imports.sh" ]; then
    echo "Error: Cannot find imports.sh"
    exit 1
fi

# Set error handling
set -euo pipefail

# Enable debug mode if requested
if [[ "${1:-}" == "--debug" ]]; then
    set -x
    echo "Debug mode enabled"
fi