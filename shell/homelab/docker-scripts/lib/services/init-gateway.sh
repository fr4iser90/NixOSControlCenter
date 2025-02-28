#!/bin/bash
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOCKER_SCRIPTS_DIR="/home/docker/docker-scripts"

source "${DOCKER_SCRIPTS_DIR}/lib/core/imports.sh"

# Guard gegen mehrfaches Laden
if [ -n "${_SECURITY_SERVICE_LOADED+x}" ]; then
    return 0
fi
_SECURITY_SERVICE_LOADED=1

# ==============================================
# Security Functions
# ==============================================

# CrowdSec Configuration
configure_crowdsec_bouncer() {
    print_status "Creating new bouncer key in CrowdSec..." "info"
    
    local BOUNCER_NAME="traefik-crowdsec-bouncer"
    local CROWDSEC_API_KEY

    # Wait for CrowdSec to be running
    while ! docker ps --filter "name=crowdsec" --filter "status=running" | grep -q crowdsec; do
        print_status "Waiting for CrowdSec to be running..." "info"
        sleep 2
    done

    # Wait for CrowdSec to be ready (cscli must respond)
    while ! docker exec crowdsec cscli bouncers list > /dev/null 2>&1; do
        print_status "Waiting for CrowdSec to be ready..." "info"
        sleep 5
    done

    # Delete existing bouncer if it exists
    if docker exec crowdsec cscli bouncers list | grep -q "${BOUNCER_NAME}"; then
        print_status "Deleting existing bouncer: ${BOUNCER_NAME}" "info"
        docker exec crowdsec cscli bouncers delete "${BOUNCER_NAME}" || true
    fi

    # Generate new bouncer key
    print_status "Generating new bouncer key..." "info"
    
    # Attempt to extract the API key using awk
    CROWDSEC_API_KEY=$(docker exec crowdsec cscli bouncers add "${BOUNCER_NAME}" | awk 'NR==3 {print $1}')
    
    # If awk failed, try using grep
    if [ -z "$CROWDSEC_API_KEY" ]; then
        CROWDSEC_API_KEY=$(docker exec crowdsec cscli bouncers add "${BOUNCER_NAME}" | grep -oP 'API key for .*: \K.*')
    fi

    # Check if the key was generated
    if [ -z "$CROWDSEC_API_KEY" ]; then
        print_status "Failed to generate CrowdSec bouncer API key" "error"
        return 1
    fi

    print_status "Successfully generated bouncer key" "success"
    print_status "New CrowdSec Bouncer Token: $CROWDSEC_API_KEY" "info"

    # Update bouncer configuration
    local TRAEFIK_DIR
    TRAEFIK_DIR=$(get_docker_dir "traefik-crowdsec")
    
    if ! update_env_file "$TRAEFIK_DIR" "traefik-crowdsec-bouncer.env" \
        "CROWDSEC_BOUNCER_API_KEY:$CROWDSEC_API_KEY"; then
        print_status "Failed to update bouncer configuration" "error"
        return 1
    fi
    
    print_status "CrowdSec Bouncer configured successfully" "success"
    return 0
}

# Traefik Security Configuration
configure_traefik_auth() {
    print_header "Configuring Traefik Authentication"
    
    print_status "These credentials will be used to access the Traefik dashboard" "info"
    export SERVICE_NAME="traefik"
    
    # Username-Eingabe mit zentraler Logik
    local username
    username=$(prompt_input "Username: " $INPUT_TYPE_USERNAME)
    
    # Passwort-Eingabe mit zentraler Logik
    local password
    password=$(prompt_input "Password: " $INPUT_TYPE_PASSWORD)

    print_status "Generating secure password hash..." "info"
    
    # Generate hashed password
    escaped_password=$(echo "$password" | sed 's/[&/]/\\&/g')
    
    local hashed_password
    hashed_password=$(nix-shell -p apacheHttpd --command "htpasswd -nbm \"$username\" \"$password\"" | cut -d ':' -f 2)
    
    if [ -z "$hashed_password" ]; then
        print_status "Failed to generate password hash" "error"
        return 1
    fi
    
    echo "Replacing placeholder with: $username:$hashed_password"

    # Update config
    sed -i "s|\${TRAEFIKUSER}|\"$username:$hashed_password\"|g" "$TRAEFIK_DIR/traefik/dynamic-conf/base-config.yml"
    
    store_service_credentials "traefik" "$username" "$password"    
    print_status "Traefik authentication configured successfully" "success"
    print_status "You can now login with:" "info"
    print_status "Username: $username" "info"
    print_status "Password: $password" "info"
    print_status "$(grep -A2 'basicAuth' "$TRAEFIK_DIR/traefik/dynamic-conf/base-config.yml")" "info"
    echo
    return 0
}

configure_traefik_ssl() {
    local TRAEFIK_DIR=$(get_docker_dir "traefik-crowdsec")
    
    if validate_email; then
        sed -i "s|\${EMAIL}|$EMAIL|g" "$TRAEFIK_DIR/traefik/traefik.yml"
        print_status "SSL configuration updated" "success"
        return 0
    fi
    return 1
}

# Main initialization function
initialize_gateway() {
    print_status "Initializing security infrastructure..." "info"

    # Auto-Setup Check am Anfang
    if prompt_confirmation "Enable automatic credential generation?"; then
        export AUTO_SETUP=1
        init_credentials_file
    fi

    local TRAEFIK_DIR=$(get_docker_dir "traefik-crowdsec")
    local DDNS_DIR=$(get_docker_dir "ddns-updater")
    
    # DNS Setup MUSS ZUERST kommen!
    print_status "Setting up DNS configuration..." "info"
    if ! update_dns_configuration; then
        print_status "Failed to configure DNS" "error"
        return 1
    fi

    # Update environment files für alle Gateway-Services
    for script in "update-crowdsec-env.sh" "update-traefik-env.sh" "update-ddns-env.sh" "update-ddns-config.sh"; do
        local script_dir
        case $script in
            update-ddns*)
                script_dir="$DDNS_DIR"
                ;;
            *)
                script_dir="$TRAEFIK_DIR"
                ;;
        esac

        local script_path="$script_dir/$script"
        if [ -f "$script_path" ]; then
            print_status "Running $script..." "info"
            bash "$script_path" || {
                print_status "Failed to run $script" "error"
                return 1
            }
        else
            print_status "Script not found: $script_path" "error"
            return 1
        fi
    done
    
    # Configure components
    configure_traefik_auth || return 1
    configure_traefik_ssl || return 1

    # Start services
    print_status "Starting Gateway Services..." "info"
    start_docker_container "traefik-crowdsec" || return 1
    start_docker_container "ddns-updater" || return 1

    # Configure bouncer
    configure_crowdsec_bouncer || return 1

    # Restart to apply changes
    restart_docker_container "traefik-crowdsec" || return 1

    print_status "Security infrastructure initialized successfully" "success"
    return 0
}
