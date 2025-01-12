#!/bin/bash

# Guard gegen mehrfaches Laden
if [ -n "${_DNS_PROVIDER_SELECT_LOADED+x}" ]; then
    return 0
fi
_DNS_PROVIDER_SELECT_LOADED=1

select_dns_provider() {
    local tmp_file=$(mktemp)
    printf "%s\n" "${providers[@]}" > "$tmp_file"
    
    local selected_provider=$(cat "$tmp_file" | fzf --prompt="Select DNS provider: ")
    rm "$tmp_file"
    
    echo "$selected_provider"
}

get_dns_credentials() {
    local selected_provider="$1"
    
    # Split genau wie in deiner alten Version
    local provider_name=$(echo "$selected_provider" | awk '{print $1}')
    local provider_code=$(echo "$selected_provider" | awk '{print $2}')
    local vars=$(echo "$selected_provider" | awk '{for(i=3;i<=NF;i++) printf $i " "; print ""}')
    
    # Exportiere für andere Scripts
    export DNS_PROVIDER_NAME="$provider_name"
    export DNS_PROVIDER_CODE="$provider_code"
    
    # Credentials holen - GENAU wie in deiner Version
    for var in $vars; do
        read -p "Enter value for $var: " value
        export "$var=$value"
    done
    
    return 0
}