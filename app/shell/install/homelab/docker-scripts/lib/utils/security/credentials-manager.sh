#!/bin/bash

# Credentials Storage File
CREDS_FILE="$HOME/homelab_tmp_credentials.txt"
FINAL_CREDS_FILE="$HOME/homelab_credentials.txt"

# Initialize credentials file (only if it doesn't exist)
init_credentials_file() {
    if [ ! -f "$CREDS_FILE" ]; then
        echo "=== Homelab Service Credentials ===" > "$CREDS_FILE"
        echo "Generated: $(date)" >> "$CREDS_FILE"
        echo "=================================" >> "$CREDS_FILE"
        echo >> "$CREDS_FILE"
    fi
}

# Store credentials for a service
store_service_credentials() {
    local service="$1"
    local username="$2"
    local password="$3"
    
    echo "Service: $service" >> "$CREDS_FILE"
    echo "Username: $username" >> "$CREDS_FILE"
    echo "Password: $password" >> "$CREDS_FILE"
    echo "-----------------------------------" >> "$CREDS_FILE"
}

# Retrieve credentials for a given service using only $CREDS_FILE
retrieve_service_credentials() {
    local service="$1"
    local file="$CREDS_FILE"

    # Überprüfen, ob die Datei existiert
    if [ ! -f "$file" ]; then
        print_status "Credentials file not found: $file" "error"
        return 1
    fi

    # Suchen nach dem Service-Block und extrahiere Username und Password
    local credentials
    credentials=$(awk -v srv="$service" '
        $1 == "Service:" && $2 == srv {
            getline;
            if ($1 == "Username:") { username = $2 }
            getline;
            if ($1 == "Password:") { password = $2 }
            print username " " password;
            exit;
        }
    ' "$file")

    # Wenn keine Credentials gefunden wurden, Fehlermeldung ausgeben und weitermachen
    if [ -z "$credentials" ]; then
        print_status "No credentials found for service: $service in $file" "error"
        return 1
    fi

    # Globale Variablen setzen, damit sie in anderen Funktionen verwendet werden können
    SERVICE_CREDENTIALS_USERNAME=$(echo "$credentials" | awk '{print $1}')
    SERVICE_CREDENTIALS_PASSWORD=$(echo "$credentials" | awk '{print $2}')

    return 0
}

# Finalize credentials file
finalize_credentials_file() {
    if [ -f "$CREDS_FILE" ]; then
        mv "$CREDS_FILE" "$FINAL_CREDS_FILE"
        chmod 600 "$FINAL_CREDS_FILE"
        print_status "Credentials saved to: $FINAL_CREDS_FILE" "success"
    fi
}