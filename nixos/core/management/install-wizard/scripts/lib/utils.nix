# Utils — prompts use colors.sh (cli-formatter palette).
{ pkgs, getModuleApi ? null, ... }:
pkgs.writeText "utils.sh" ''
#!/usr/bin/env bash

check_script_execution() {
    local required_var="$1"
    local main_function="$2"

    [[ "''${BASH_SOURCE[1]}" == "''${0}" ]] || return 0

    if [[ -z "''${!required_var:-}" ]]; then
        echo "Error: Environment not properly initialized (''${required_var} missing)"
        exit 1
    fi
    # shellcheck disable=SC2086
    $main_function
}

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

    if declare -F ncc_dry_run >/dev/null 2>&1 && ncc_dry_run; then
        ncc_dry_skip "backup" "$file"
        return 0
    fi

    if [ -f "$file" ]; then
        local backup_root backup_file

        if echo "$file" | grep -q "^/etc/ssh/"; then
            backup_root="/var/backup/nixos/ssh"
            backup_file="$backup_root/$(basename "$file").backup.$(date +%Y%m%d_%H%M%S)"
        elif echo "$file" | grep -q "^/etc/nixos/"; then
            backup_root="/var/backup/nixos/systemConfig"
            backup_file="$backup_root/$(basename "$file").backup.$(date +%Y%m%d_%H%M%S)"
        else
            backup_root="/var/backup/nixos/systemConfig"
            backup_file="$backup_root/$(basename "$file").backup.$(date +%Y%m%d_%H%M%S)"
        fi

        if [ ! -d "$backup_root" ]; then
            mkdir -p "$backup_root"
            chmod 700 "$backup_root" 2>/dev/null || sudo chmod 700 "$backup_root" 2>/dev/null || true
            chown root:root "$backup_root" 2>/dev/null || sudo chown root:root "$backup_root" 2>/dev/null || true
        else
            mkdir -p "$backup_root"
        fi

        if cp "$file" "$backup_file" 2>/dev/null || sudo cp "$file" "$backup_file" 2>/dev/null; then
            chmod 600 "$backup_file" 2>/dev/null || sudo chmod 600 "$backup_file" 2>/dev/null || true
            chown root:root "$backup_file" 2>/dev/null || sudo chown root:root "$backup_file" 2>/dev/null || true
            if echo "$file" | grep -q "^/etc/ssh/"; then
                ls -t "$backup_root"/$(basename "$file").backup.* 2>/dev/null | tail -n +6 | xargs -r rm -f 2>/dev/null || true
            else
                ls -t "$backup_root"/$(basename "$file").backup.* 2>/dev/null | tail -n +11 | xargs -r rm -f 2>/dev/null || true
            fi
            log_info "Created backup: $backup_file"
            return 0
        fi

        log_error "Failed to create backup of $file"
        return 1
    fi
}

ask_user() {
    local prompt="$1"
    local default="''${2:-N}"
    local response

    if [[ "$default" == "Y" ]]; then
        printf '%b' "''${BLUE}[?]''${NC} $prompt [Y/n] "
    else
        printf '%b' "''${BLUE}[?]''${NC} $prompt [y/N] "
    fi

    read -r response
    response=''${response:-$default}

    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

select_model() {
    local options=("minimal" "desktop" "server" "gaming")
    local selected

    printf '%b\n' "''${BLUE}[?]''${NC} Select installation model:"
    select selected in "''${options[@]}"; do
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

declare -a util_functions=(
    "check_script_execution"
    "check_root"
    "ensure_dir"
    "backup_file"
    "ask_user"
    "select_model"
    "confirm_installation"
)

for func in "''${util_functions[@]}"; do
    export -f "$func"
done

check_script_execution "LIB_DIR" "log_info 'Utils initialized'"

if [[ -z "''${COLORS_IMPORTED:-}" ]]; then
    source "$(dirname "''${BASH_SOURCE[0]}")/colors.sh"
fi

if ! command -v log_info &> /dev/null; then
    source "$(dirname "''${BASH_SOURCE[0]}")/logging.sh"
fi
''
