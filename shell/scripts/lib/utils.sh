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
        # Determine backup location based on file path
        local backup_root
        local backup_file
        
        if echo "$file" | grep -q "^/etc/ssh/"; then
            # SSH config → use SSH backup
            backup_root="/var/backup/nixos/ssh"
            backup_file="$backup_root/$(basename "$file").backup.$(date +%Y%m%d_%H%M%S)"
            # Create directory if it doesn't exist (ActivationScript should have created it)
            if [ ! -d "$backup_root" ]; then
                mkdir -p "$backup_root"
                chmod 700 "$backup_root" 2>/dev/null || sudo chmod 700 "$backup_root" 2>/dev/null || true
                chown root:root "$backup_root" 2>/dev/null || sudo chown root:root "$backup_root" 2>/dev/null || true
            else
                mkdir -p "$backup_root"  # Ensure it exists
            fi
            # Create backup file and set permissions (600 = read/write for owner only)
            if cp "$file" "$backup_file" 2>/dev/null || sudo cp "$file" "$backup_file" 2>/dev/null; then
                chmod 600 "$backup_file" 2>/dev/null || sudo chmod 600 "$backup_file" 2>/dev/null || true
                chown root:root "$backup_file" 2>/dev/null || sudo chown root:root "$backup_file" 2>/dev/null || true
                # Cleanup old backups (keep last 5)
                ls -t "$backup_root"/$(basename "$file").backup.* 2>/dev/null | tail -n +6 | xargs -r rm -f 2>/dev/null || sudo xargs -r rm -f 2>/dev/null || true
                log_info "Created backup: $backup_file"
                return 0
            fi
        elif echo "$file" | grep -q "^/etc/nixos/"; then
            # NixOS config → use config backup
            backup_root="/var/backup/nixos/configs"
            backup_file="$backup_root/$(basename "$file").backup.$(date +%Y%m%d_%H%M%S)"
            # Create directory if it doesn't exist (ActivationScript should have created it)
            if [ ! -d "$backup_root" ]; then
                mkdir -p "$backup_root"
                chmod 700 "$backup_root" 2>/dev/null || sudo chmod 700 "$backup_root" 2>/dev/null || true
                chown root:root "$backup_root" 2>/dev/null || sudo chown root:root "$backup_root" 2>/dev/null || true
            else
                mkdir -p "$backup_root"  # Ensure it exists
            fi
            # Create backup file and set permissions (600 = read/write for owner only)
            if cp "$file" "$backup_file" 2>/dev/null || sudo cp "$file" "$backup_file" 2>/dev/null; then
                chmod 600 "$backup_file" 2>/dev/null || sudo chmod 600 "$backup_file" 2>/dev/null || true
                chown root:root "$backup_file" 2>/dev/null || sudo chown root:root "$backup_file" 2>/dev/null || true
                # Cleanup old backups (keep last 10)
                ls -t "$backup_root"/$(basename "$file").backup.* 2>/dev/null | tail -n +11 | xargs -r rm -f 2>/dev/null || sudo xargs -r rm -f 2>/dev/null || true
                log_info "Created backup: $backup_file"
                return 0
            fi
        else
            # Generic file → use config backup location
            backup_root="/var/backup/nixos/configs"
            backup_file="$backup_root/$(basename "$file").backup.$(date +%Y%m%d_%H%M%S)"
            # Create directory if it doesn't exist (ActivationScript should have created it)
            if [ ! -d "$backup_root" ]; then
                mkdir -p "$backup_root"
                chmod 700 "$backup_root" 2>/dev/null || sudo chmod 700 "$backup_root" 2>/dev/null || true
                chown root:root "$backup_root" 2>/dev/null || sudo chown root:root "$backup_root" 2>/dev/null || true
            else
                mkdir -p "$backup_root"  # Ensure it exists
            fi
            # Create backup file and set permissions (600 = read/write for owner only)
            if cp "$file" "$backup_file" 2>/dev/null || sudo cp "$file" "$backup_file" 2>/dev/null; then
                chmod 600 "$backup_file" 2>/dev/null || sudo chmod 600 "$backup_file" 2>/dev/null || true
                chown root:root "$backup_file" 2>/dev/null || sudo chown root:root "$backup_file" 2>/dev/null || true
                # Cleanup old backups (keep last 10)
                ls -t "$backup_root"/$(basename "$file").backup.* 2>/dev/null | tail -n +11 | xargs -r rm -f 2>/dev/null || sudo xargs -r rm -f 2>/dev/null || true
                log_info "Created backup: $backup_file"
                return 0
            fi
        fi
        
        log_error "Failed to create backup of $file"
        return 1
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