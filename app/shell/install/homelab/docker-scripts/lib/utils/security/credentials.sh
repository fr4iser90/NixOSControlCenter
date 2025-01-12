#!/bin/bash

# Global settings with defaults
SHOW_CREDENTIALS=false  # Default: mask credentials

# Function to ask for credential visibility preference
ask_credential_preference() {
    print_header "Credential Visibility"
    print_status "Do you want to see sensitive information during setup?" "info"
    print_status "This includes passwords, API keys, and tokens" "info"
    print_status "Default is masked (recommended)" "info"
    echo

    if prompt_confirmation "Show sensitive information?"; then
        SHOW_CREDENTIALS=true
        print_status "Credentials will be visible!" "warning"
        print_status "You can toggle this later with toggle_credential_visibility" "info"
    else
        SHOW_CREDENTIALS=false
        print_status "Credentials will be masked (recommended)" "success"
    fi
}

# Function to toggle credential visibility
toggle_credential_visibility() {
    if [ "$SHOW_CREDENTIALS" = true ]; then
        SHOW_CREDENTIALS=false
        print_status "Credentials will be masked" "warning"
    else
        print_status "⚠️  WARNING: This will show sensitive information!" "warning"
        if prompt_confirmation "Are you sure you want to show credentials?"; then
            SHOW_CREDENTIALS=true
            print_status "Credentials will be visible!" "error"
        fi
    fi
}

# Function to display credential based on settings
display_credential() {
    local value="$1"
    local label="${2:-Value}"
    
    if [ "$SHOW_CREDENTIALS" = true ]; then
        echo -e "${label}: ${YELLOW}${value}${NC}"
    else
        echo -e "${label}: ${YELLOW}********${NC}"
    fi
}

# Function to handle sensitive input with visibility toggle
prompt_sensitive() {
    local prompt_text="$1"
    local label="${2:-Value}"
    local value
    
    value=$(prompt_input "$prompt_text" $INPUT_TYPE_SENSITIVE)
    display_credential "$value" "$label"
    echo "$value"
}