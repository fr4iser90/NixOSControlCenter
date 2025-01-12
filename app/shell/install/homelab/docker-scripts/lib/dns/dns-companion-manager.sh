# Traefik Companion Konfiguration
declare -ga TRAEFIK_COMPANIONS=(
    "cloudflare:cloudflare"
)

update_companion_config() {
    local provider_code="$1"

    for companion in "${TRAEFIK_COMPANIONS[@]}"; do
        IFS=':' read -r comp_provider comp_name <<< "$companion"

        if [[ "$provider_code" == "$comp_provider" ]]; then
            print_status "Updating Traefik $comp_name companion..." "info"

            local COMPANION_DIR=$(get_docker_dir "$comp_name")

            if [ ! -f "$COMPANION_DIR/update-env.sh" ]; then
                print_status "Update script not found at: $COMPANION_DIR/update-env.sh" "error"
                return 1
            fi

            if ! bash "$COMPANION_DIR/update-env.sh"; then
                print_status "Failed to update $comp_name companion" "error"
                return 1
            fi

            print_status "Traefik $comp_name companion updated" "success"
            return 0
        fi
    done

    return 0
}
