#!/bin/bash
export TEST_MODE=1
#export AUTO_SETUP=0
# Zuerst die benötigten Funktionen laden
source "${DOCKER_LIB_DIR}/utils/format/output.sh"
source "${DOCKER_LIB_DIR}/utils/security/credentials-manager.sh"
source "${DOCKER_LIB_DIR}/utils/system/string.sh"     
source "${DOCKER_LIB_DIR}/utils/security/crypto.sh"

# Guard against multiple inclusion
if [ -z "${_PROMPT_SH+x}" ]; then
    _PROMPT_SH=1

    # Input types as constants - EXPORTIERT für andere Scripts
    export INPUT_TYPE_NORMAL=1
    export INPUT_TYPE_SENSITIVE=2
    export INPUT_TYPE_EMAIL=3
    export INPUT_TYPE_USERNAME=4
    export INPUT_TYPE_PASSWORD=5
fi

# Debug Funktion
debug() {
    [[ "${DEBUG:-0}" == "1" ]] && echo "DEBUG: $*" >&2
}

print_prompt() {
    local message="$1"
    echo -e "\n${BLUE}==================================================
        $message        
==================================================${NC}\n"
}

# Generic input prompt with validation
prompt_input() {
    local prompt_text="$1"
    local input_type="${2:-$INPUT_TYPE_NORMAL}"
    local value

    debug "prompt_input called with text='$prompt_text' type='$input_type'"

    # Initialize CURRENT_USERNAME if not set
    CURRENT_USERNAME=${CURRENT_USERNAME:-""}

    # Auto-Setup für USERNAME und PASSWORD
    if [ "${AUTO_SETUP:-0}" -eq 1 ]; then
        case $input_type in
            $INPUT_TYPE_USERNAME)
                value="auto_user_$(generate_random_string 8)"
                print_status "Auto-generated username" "info"
                # Speichere temporär für spätere Verwendung
                CURRENT_USERNAME="$value"
                echo "$value"
                return 0
                ;;
            $INPUT_TYPE_PASSWORD)
                value=$(generate_secure_password)
                print_status "Auto-generated password" "info"
                # Speichere Credentials wenn Username vorhanden
                if [ -n "$CURRENT_SERVICE" ] && [ -n "$CURRENT_USERNAME" ]; then
                    store_service_credentials "$CURRENT_SERVICE" "$CURRENT_USERNAME" "$value"
                    unset CURRENT_USERNAME
                    unset CURRENT_SERVICE
                fi
                echo "$value"
                return 0
                ;;
        esac
    fi

    case $input_type in
        $INPUT_TYPE_USERNAME)
            debug "Handling USERNAME input"
            while true; do
                echo -en "${BLUE}Username${NC} > " > /dev/tty
                read value < /dev/tty
                debug "Got username='$value'"
                if [ -n "$value" ]; then
                    # Set CURRENT_USERNAME auch bei manuellem Input
                    CURRENT_USERNAME="$value"
                    echo "$value"
                    return 0
                fi
                print_status "Username cannot be empty" "error"
            done
            ;;
            
        $INPUT_TYPE_PASSWORD|$INPUT_TYPE_SENSITIVE)
            debug "Handling PASSWORD input"
            while true; do
                echo -en "${BLUE}Password${NC} > " > /dev/tty
                read -s value < /dev/tty
                echo > /dev/tty
                debug "Got password length=${#value}"
                
                local has_warning=0
                
                if [[ ${#value} -lt 8 ]]; then
                    if [[ $TEST_MODE -eq 1 ]]; then
                        print_status "Warning: Password should be at least 8 characters" "warn" > /dev/tty
                        has_warning=1
                    else
                        print_status "Password must be at least 8 characters" "error" > /dev/tty
                        continue
                    fi
                fi
                
                if ! [[ $value =~ [0-9] ]]; then
                    if [[ $TEST_MODE -eq 1 ]]; then
                        print_status "Warning: Password should contain at least one number" "warn" > /dev/tty
                        has_warning=1
                    else
                        print_status "Password must contain at least one number" "error" > /dev/tty
                        continue
                    fi
                fi
                
                if ! [[ $value =~ [^a-zA-Z0-9] ]]; then
                    if [[ $TEST_MODE -eq 1 ]]; then
                        print_status "Warning: Password should contain at least one special character" "warn" > /dev/tty
                        has_warning=1
                    else
                        print_status "Password must contain at least one special character" "error" > /dev/tty
                        continue
                    fi
                fi

                if [[ $TEST_MODE -eq 1 && $has_warning -eq 1 ]]; then
                    print_status "Continuing with weak password (test mode)" "warn" > /dev/tty
                fi

                echo -en "${BLUE}Confirm${NC} > " > /dev/tty
                read -s value2 < /dev/tty
                echo > /dev/tty
                
                if [ "$value" == "$value2" ]; then
                    print_status "Password validated" "success" > /dev/tty
                    echo "$value"
                    return 0
                else
                    print_status "Passwords do not match" "error" > /dev/tty
                fi
            done
            ;;
            
        $INPUT_TYPE_EMAIL)
            while true; do
                echo -en "${BLUE}Email${NC} > " > /dev/tty
                read value < /dev/tty
                if [[ "$value" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
                    echo "$value"
                    return 0
                else
                    echo "Invalid email format. Please try again."
                fi
            done
            ;;
            
        *)
            echo -en "${BLUE}${prompt_text}${NC} > " > /dev/tty
            read value < /dev/tty
            echo "$value"
            return 0
            ;;
    esac
}

# Specialized prompts using the generic function
prompt_email() {
    local prompt_text="${1:-Enter email address}"
    prompt_input "$prompt_text" $INPUT_TYPE_EMAIL
}

prompt_password() {
    local prompt_text="${1:-Enter password}"
    prompt_input "$prompt_text" $INPUT_TYPE_PASSWORD
}

prompt_confirmation() {
    local prompt_text="${1:-Are you sure?}"
    while true; do
        echo -e "${BLUE}$prompt_text [y/N]${NC}" > /dev/tty
        echo -n "> " > /dev/tty
        read -r yn < /dev/tty
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no."
        esac
    done
}
