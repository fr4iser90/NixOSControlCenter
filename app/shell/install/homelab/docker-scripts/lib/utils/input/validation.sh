#!/bin/bash

# Guard gegen mehrfaches Laden
if [ -n "${_VALIDATION_LOADED+x}" ]; then
    return 0
fi
_VALIDATION_LOADED=1

# Domain Validierung
validate_domain() {
    if [ -z "$DOMAIN" ]; then
        print_status "DOMAIN environment variable is not set" "error"
        return 1
    fi
    return 0
}

# Email Validierung
validate_email() {
    if [ -z "$CERTEMAIL" ]; then
        print_status "CERTEMAIL environment variable is not set" "error"
        return 1
    fi
    return 0
}

# Zentrale Validierungsfunktion
validate_input() {
    local input="$1"
    local type="$2"
    
    case "$type" in
        "domain")
            validate_domain "$input"
            ;;
        "email") 
            validate_email "$input"
            ;;
        *)
            return 0
            ;;
    esac
    
    return $?
}