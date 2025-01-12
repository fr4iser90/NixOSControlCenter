#!/bin/bash

# Guard gegen mehrfaches Laden
if [ -n "${_IMPORTS_LOADED+x}" ]; then
    return 0
fi
_IMPORTS_LOADED=1

# Zuerst script-header laden (enthält DOCKER_SCRIPTS_DIR)
source "${DOCKER_SCRIPTS_DIR}/lib/core/script-header.sh"

# Dann die Core-Module
source "${DOCKER_SCRIPTS_DIR}/lib/core/containers.sh"
source "${DOCKER_SCRIPTS_DIR}/lib/core/path.sh"

# Utils - Format (brauchen wir für Ausgaben)
source "${DOCKER_LIB_DIR}/utils/format/colors.sh"
source "${DOCKER_LIB_DIR}/utils/format/output.sh"

# Utils - Input
source "${DOCKER_LIB_DIR}/utils/input/prompt.sh"
source "${DOCKER_LIB_DIR}/utils/input/validation.sh"

# Utils - Security
source "${DOCKER_LIB_DIR}/utils/security/credentials.sh"
source "${DOCKER_LIB_DIR}/utils/security/crypto.sh"
source "${DOCKER_LIB_DIR}/utils/security/hash.sh"
source "${DOCKER_LIB_DIR}/utils/security/credentials-manager.sh"

# Utils - System
source "${DOCKER_LIB_DIR}/utils/system/file.sh"
source "${DOCKER_LIB_DIR}/utils/system/user.sh"
source "${DOCKER_LIB_DIR}/utils/system/string.sh"

# Services
source "${DOCKER_LIB_DIR}/services/docker.sh"
source "${DOCKER_LIB_DIR}/services/init-gateway.sh"
source "${DOCKER_LIB_DIR}/services/init-services.sh"
source "${DOCKER_LIB_DIR}/services/permissions.sh"

# DNS
source "${DOCKER_LIB_DIR}/dns/dns-setup.sh"
source "${DOCKER_LIB_DIR}/dns/dns-providers-list.sh"
source "${DOCKER_LIB_DIR}/dns/dns-provider-select.sh"
source "${DOCKER_LIB_DIR}/dns/dns-companion-manager.sh"


# Network utilities
source "${DOCKER_LIB_DIR}/utils/network/router.sh"
source "${DOCKER_LIB_DIR}/utils/network/ports.sh"
verify_imports() {
    local required_vars=(
        "DOCKER_BASE_DIR"     # from path.sh
        "SHOW_CREDENTIALS"    # from credentials.sh
        "INFO"               # from colors.sh
    )

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            if type print_status >/dev/null 2>&1; then
                print_status "Required variable $var is not set" "error"
            else
                echo "Error: Required variable $var is not set"
            fi
            exit 1
        fi
    done

    if type print_status >/dev/null 2>&1; then
        print_status "All required imports verified" "success"
    fi
}

verify_imports