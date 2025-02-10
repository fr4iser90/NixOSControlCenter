#!/bin/bash

# Guard gegen mehrfaches Laden
if [ -n "${_DNS_PROVIDER_SELECT_LOADED+x}" ]; then
    return 0
fi
_DNS_PROVIDER_SELECT_LOADED=1

ddns_env_file="${DOCKER_BASE_DIR}/gateway-management/ddns-updater/ddns-updater.env"

select_dns_provider() {
    local tmp_file=$(mktemp)
    printf "%s\n" "${providers[@]}" > "$tmp_file"
    
    local selected_provider=$(cat "$tmp_file" | fzf --prompt="Select DNS provider: ")
    rm "$tmp_file"
    
    echo "$selected_provider"
}

save_ddns_env_var() {
    local key="$1"
    local value="$2"
    local env_file="$ddns_env_file"

    # Falls die Datei nicht existiert, erstellen
    touch "$env_file"

    # Falls der Key schon existiert, ersetze ihn
    if grep -q "^$key=" "$env_file"; then
        sed -i "s|^$key=.*|$key=$value|" "$env_file"
    else
        echo "$key=$value" >> "$env_file"
    fi
}

get_dns_credentials() {
    local selected_provider="$1"
    
    # Split 
    local provider_name=$(echo "$selected_provider" | awk '{print $1}')
    local provider_code=$(echo "$selected_provider" | awk '{print $2}')
    local vars=$(echo "$selected_provider" | awk '{for(i=3;i<=NF;i++) printf $i " "; print ""}')
    
    export DNS_PROVIDER_CODE="$provider_code"
    save_ddns_env_var "DNS_PROVIDER_CODE" "$provider_code"

    # Credentials holen
    for var in $vars; do
        read -p "Enter value for $var: " value
        export "$var=$value"
        save_ddns_env_var "$var" "$value"
    done
    
    return 0
}