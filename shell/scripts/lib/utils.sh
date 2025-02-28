#!/usr/bin/env bash

# =====================
# = Script Management =
# =====================

check_script_execution() {
    local required_var="$1"
    local main_function="$2"
    
    if [[ "${BASH_SOURCE[1]}" == "${0}" ]]; then
        if [[ -z "${!required_var:-}" ]]; then
            echo "Error: Environment not properly initialized (${required_var} missing)"
            exit 1
        fi
        $main_function
    fi
}

# ===================
# = System Helpers =
# ===================

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        if command -v sudo >/dev/null 2>&1; then
            if ! sudo -n true 2>/dev/null; then
                log_error "Neither root privileges nor passwordless sudo available"
                log_info "Please add NOPASSWD entry to sudoers for this script"
                exit 1
            fi
            export SUDO="sudo"
        else
            log_error "Neither root privileges nor sudo available"
            exit 1
        fi
    else
        export SUDO=""
    fi
}

# ====================
# = File Management =
# ====================

ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            log_error "Failed to create directory: $dir"
            return 1
        }
        log_info "Created directory: $dir"
    fi
}

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup" || {
            log_error "Failed to create backup of $file"
            return 1
        }
        log_info "Created backup: $backup"
    fi
}

# =======================
# = User Interaction =
# =======================

ask_user() {
    local prompt="$1"
    local default="${2:-N}"  # Default to No if not specified
    local response
    
    if [[ "$default" == "Y" ]]; then
        echo -en "${BLUE}[?]${NC} $prompt [Y/n] "
    else
        echo -en "${BLUE}[?]${NC} $prompt [y/N] "
    fi
    
    read -r response
    response=${response:-$default}
    
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
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
        log_error "Invalid selection. Please try again."
    done
}

confirm_installation() {
    ask_user "Ready to proceed with installation?" "N"
}

# =============
# = Exports =
# =============

declare -a util_functions=(
    "check_script_execution"
    "check_root"
    "ensure_dir"
    "backup_file"
    "ask_user"
    "select_model"
    "confirm_installation"
)

for func in "${util_functions[@]}"; do
    export -f "$func"
done

# Check environment
check_script_execution "LIB_DIR" "log_info 'Utils initialized'"

# Ensure required dependencies are available
if [[ -z "$COLORS_IMPORTED" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi

if ! command -v log_info &> /dev/null; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi