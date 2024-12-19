#!/usr/bin/env bash

# Import colors if not already imported
if [[ -z "$COLORS_IMPORTED" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi

# Ensure logging is loaded
if ! command -v log_info &> /dev/null; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Prüfe ob wir root sind
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "Please run as root"
        exit 1
    fi
}

# Verzeichnis erstellen wenn es nicht existiert
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    fi
}

# Backup einer Datei erstellen
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Created backup of $file"
    fi
}

# User interaction functions
ask_user() {
    local prompt="$1"
    local response
    
    echo -en "${BLUE}[?]${NC} $prompt [y/N] "
    read -r response
    
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

select_model() {
    local options=("minimal" "desktop" "server" "gaming")
    local selected
    
    echo -e "${BLUE}[?]${NC} Select installation model:"
    select selected in "${options[@]}"; do
        if [[ -n "$selected" ]]; then
            echo "$selected"
            return 0
        fi
        echo "Invalid selection. Please try again."
    done
}

confirm_installation() {
    ask_user "Ready to proceed with installation?"
}

# Export functions
export -f check_root ensure_dir backup_file ask_user select_model confirm_installation