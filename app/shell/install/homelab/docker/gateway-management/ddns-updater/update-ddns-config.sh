#!/bin/bash

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOCKER_SCRIPTS_DIR="/home/docker/docker-scripts"

# Source core imports
source "${DOCKER_SCRIPTS_DIR}/lib/core/imports.sh"

# Guard gegen mehrfaches Laden
if [ -n "${_DDNS_CONFIG_LOADED+x}" ]; then
    return 0
fi
_DDNS_CONFIG_LOADED=1

# Script configuration
SERVICE_NAME="ddns-updater"
CONF_FILE="config/ddclient.conf"
ENV_FILE="ddns-updater.env"

print_header "Updating DDNS Configuration"

# Get service directory
BASE_DIR=$(get_docker_dir "$SERVICE_NAME")
if [ $? -ne 0 ]; then
    print_status "Failed to get $SERVICE_NAME directory" "error"
    exit 1
fi

# Lade Umgebungsvariablen aus der ENV-Datei
load_env_vars() {
    if [ -f "$BASE_DIR/$ENV_FILE" ]; then
        export $(grep -v '^#' "$BASE_DIR/$ENV_FILE" | xargs)
    else
        print_status "ENV file not found" "error"
        exit 1
    fi
}

# Funktion zum Ersetzen der Platzhalter in der Konfigurationsdatei
replace_placeholders() {
    print_status "Replacing placeholders in ddclient.conf..." "info"

    # Falls eine Variable nicht gesetzt ist, setze einen Standardwert
    DOMAIN="${DOMAIN:-defaultdomain.com}"
    CF_TOKEN="${CF_TOKEN:-default_cf_token}"
    GANDIV5_PERSONAL_ACCESS_TOKEN="${GANDIV5_PERSONAL_ACCESS_TOKEN:-default_token}"
    PORKBUN_API_KEY="${PORKBUN_API_KEY:-default_api_token}"
    PORKBUN_SECRET_API_KEY="${PORKBUN_SECRET_API_KEY:-default_secret_api_key}"

    # Ersetze die Platzhalter
    sed -i -e "s/\${DOMAIN}/$DOMAIN/g" \
           -e "s/\${CF_TOKEN}/$CF_TOKEN/g" \
           -e "s/\${GANDIV5_PERSONAL_ACCESS_TOKEN}/$GANDIV5_PERSONAL_ACCESS_TOKEN/g" \
           "$BASE_DIR/$CONF_FILE"
}

update_dns_config() {
    # Validate domain
    print_status "Validating domain..." "info"
    if ! validate_domain; then
        print_status "Domain validation failed" "error"
        return 1
    fi

    print_status "Updating ddclient configuration for $DNS_PROVIDER_CODE" "info"

    # Das gewünschte Protokoll entnehmen (z.B. cloudflare, he.net, etc.)
    protocol_to_uncomment="$DNS_PROVIDER_CODE"

    if [ -z "$protocol_to_uncomment" ]; then
        print_status "Please provide a protocol (e.g. cloudflare, he.net, etc.)" "error"
        return 1
    fi

    # Backup erstellen
    cp "$BASE_DIR/$CONF_FILE" "$BASE_DIR/$CONF_FILE.bak"

    # Platzhalter ersetzen
    replace_placeholders

    # Cloudflare-Block entkommentieren, ohne den Rest zu beeinflussen
    awk -v protocol="$protocol_to_uncomment" '
    BEGIN {
        start_block = 0
        end_block = 0
    }

    /^##/ {
        if (start_block && /## /) {
            end_block = 1
        }
        if (end_block) exit
    }

    /^## / {
        if (start_block == 0 && tolower($0) ~ tolower(protocol)) {
            start_block = 1
        }
    }

    {
        if (start_block && !end_block) {
            sub(/^##\s*/, "");
            sub(/^#\s*/, "");
        }
        print
    }
    ' "$BASE_DIR/$CONF_FILE" > "$BASE_DIR/$CONF_FILE.tmp"

    # Originaldatei mit der bearbeiteten Version überschreiben
    mv "$BASE_DIR/$CONF_FILE.tmp" "$BASE_DIR/$CONF_FILE"

    print_status "DDNS configuration updated successfully" "success"
    return 0
}

# Run if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_env_vars  # Lade die Umgebungsvariablen
    if ! update_dns_config; then
        exit 1
    fi
fi
