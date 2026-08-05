#!/usr/bin/env bash
# Shared GUI helpers for the install shell.
# Answers file: KEY=shell-quoted-value lines (written by install_wizard.py)

ncc_gui_available() {
    [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]] || return 1
    command -v python3 >/dev/null 2>&1 || return 1
    python3 -c "import tkinter" 2>/dev/null || return 1
    return 0
}

ncc_install_ui_prefer_gui() {
    local mode="${NCC_INSTALL_UI:-auto}"
    case "$mode" in
        gui) return 0 ;;
        tui|fzf|terminal) return 1 ;;
        auto|*)
            ncc_gui_available && return 0
            return 1
            ;;
    esac
}

# Ensure answers file path exists (export for later steps)
ncc_gui_ensure_answers_file() {
    if [[ -z "${NCC_GUI_ANSWERS_FILE:-}" ]]; then
        export NCC_GUI_ANSWERS_FILE="${TMPDIR:-/tmp}/ncc-gui-answers-$$"
    fi
}

# Read a key from NCC_GUI_ANSWERS_FILE (if present and non-empty)
ncc_gui_answer() {
    local key="$1"
    local file="${NCC_GUI_ANSWERS_FILE:-}"
    [[ -n "$file" && -f "$file" ]] || return 1
    grep -q "^${key}=" "$file" 2>/dev/null || return 1

    local value
    value="$(
        set -a
        # shellcheck disable=SC1090
        source "$file" 2>/dev/null || true
        set +a
        eval "printf '%s' \"\${$key-}\""
    )" || return 1

    # PACKAGE_MODULES may be intentionally empty (= no packages)
    if [[ "$key" == "PACKAGE_MODULES" ]]; then
        printf '%s\n' "$value"
        return 0
    fi

    [[ -n "$value" ]] || return 1
    printf '%s\n' "$value"
    return 0
}

# Apply PACKAGE_MODULES from GUI answers (or optional fallback string).
ncc_apply_gui_package_modules() {
    local fallback="${1-}"
    local mods=""
    if declare -F ncc_gui_answer >/dev/null 2>&1; then
        if mods=$(ncc_gui_answer PACKAGE_MODULES 2>/dev/null); then
            :
        elif [[ -n "$fallback" ]]; then
            mods="$fallback"
        else
            return 0
        fi
    elif [[ -n "$fallback" ]]; then
        mods="$fallback"
    else
        return 0
    fi

    if [[ -z "$mods" ]]; then
        write_packages_config || return 1
    else
        # shellcheck disable=SC2206
        local arr=($mods)
        write_packages_config "${arr[@]}" || return 1
    fi
    return 0
}

# Apply ADMIN_USER from GUI answers into core/base/user.
ncc_apply_gui_admin_user() {
    local admin=""
    admin=$(ncc_gui_answer ADMIN_USER 2>/dev/null) || return 0
    [[ -n "$admin" ]] || return 0
    write_user_config "    \"$admin\" = {
      role = \"admin\";
      defaultShell = \"zsh\";
      autoLogin = false;
    };" || return 1
    return 0
}

# Write/overwrite one KEY=value in NCC_GUI_ANSWERS_FILE (shell-quoted).
ncc_gui_write_answer() {
    local key="$1"
    local value="$2"
    ncc_gui_ensure_answers_file
    local file="$NCC_GUI_ANSWERS_FILE"
    touch "$file"
    if grep -q "^${key}=" "$file" 2>/dev/null; then
        grep -v "^${key}=" "$file" >"${file}.tmp" || true
        mv "${file}.tmp" "$file"
    fi
    printf '%s=%q\n' "$key" "$value" >>"$file"
}

# Single-shot GUI ask. Types: text | yesno | choice | password
ncc_gui_ask() {
    local ask_type="$1"
    shift
    local gui_dir
    if [[ -n "${UI_DIR:-}" ]]; then
        gui_dir="${UI_DIR}/gui"
    else
        gui_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    local ask_py="${gui_dir}/gui_ask.py"
    [[ -f "$ask_py" ]] || return 2

    if ! ncc_gui_available; then
        return 2
    fi

    local out rc
    set +e
    out="$(python3 "$ask_py" "$ask_type" "$@")"
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
        printf '%s\n' "$out"
        return 0
    fi
    return "$rc"
}

export -f ncc_gui_available
export -f ncc_install_ui_prefer_gui
export -f ncc_gui_ensure_answers_file
export -f ncc_gui_answer
export -f ncc_gui_write_answer
export -f ncc_gui_ask
export -f ncc_apply_gui_package_modules
export -f ncc_apply_gui_admin_user
