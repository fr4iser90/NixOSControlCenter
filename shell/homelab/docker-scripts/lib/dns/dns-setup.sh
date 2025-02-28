#!/bin/bash

if [ -n "${_DNS_SETUP_LOADED+x}" ]; then
    return 0
fi
_DNS_SETUP_LOADED=1

# Main update function
update_dns_configuration() {
    # 1. Select DNS provider first
    local selected_provider=$(select_dns_provider)
    if [ $? -ne 0 ]; then
        print_status "DNS provider selection failed" "error"
        return 1
    fi

    # 2. Save provider info   get SHOW_CREDENTIALS from credentials first 
    IFS=' ' read -r provider_name provider_code provider_vars <<< "$selected_provider"
    export DNS_PROVIDER_CODE="$provider_code"

    # 3. Get and save credentials
    if ! get_dns_credentials "$selected_provider"; then
        print_status "Failed to get DNS credentials" "error"
        return 1
    fi

    # 4. Update companion if available
    if ! update_companion_config "$DNS_PROVIDER_CODE"; then
        return 1
    fi

    print_status "DNS configuration completed with $DNS_PROVIDER_CODE provider" "success"
    return 0
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    print_header "DNS Configuration Setup"
    update_dns_configuration || exit 1
fi