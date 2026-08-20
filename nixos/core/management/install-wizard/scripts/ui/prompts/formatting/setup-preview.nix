# Setup preview — colors from cli-formatter palette (colors.sh).
{ pkgs, getModuleApi ? null, ... }:
pkgs.writeText "setup-preview.sh" ''
#!/usr/bin/env bash
set -euo pipefail

source "$CORE_DIR/imports.sh"

if [[ -n "''${LIB_DIR:-}" && -f "$LIB_DIR/colors.sh" && -z "''${COLORS_IMPORTED:-}" ]]; then
  # shellcheck disable=SC1091
  source "$LIB_DIR/colors.sh"
fi

declare -r PREVIEW_WIDTH=40

generate_preview() {
    local selection="$1"
    local clean_selection
    clean_selection=$(clean_selection_string "$selection") || return 1
    generate_header "$clean_selection"
    generate_description "$clean_selection"
    generate_features "$clean_selection"
    generate_dependencies "$clean_selection"
    return 0
}
export -f generate_preview

clean_selection_string() {
    echo "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
        -e 's/📦 //' -e 's/🔧 //' -e 's/⚙️  //' \
        -e 's/📁 //' -e 's/📋 //' -e 's/🔄 //' \
        -e 's/🖥️  //' -e 's/🤖 //' \
        -e 's/ /-/g' | tr '[:upper:]' '[:lower:]'
}
export -f clean_selection_string

generate_header() {
    local title="$1"
    printf '%b\n' "''${BLUE}''${BOLD}''${title}''${NC}"
    echo "------------------------------------"
}
export -f generate_header

generate_description() {
    local selection="$1"
    echo
    get_setup_description "$selection"
}
export -f generate_description

generate_features() {
    local selection="$1"
    echo
    printf '%b\n' "''${BOLD}Type:''${NC} ''${SETUP_TYPES[$selection]:-N/A}"
    printf '%b\n' "''${BOLD}Features:''${NC}"
    local features_text=''${SETUP_FEATURES[$selection]:-N/A}
    if [[ "$features_text" == "N/A" || -z "$features_text" ]]; then
        echo "  - No specific features listed."
    else
        echo "$features_text" | tr '|' '\n' | sed 's/^/  - /'
    fi
}
export -f generate_features

generate_dependencies() {
    local selection="$1"
    if [[ -n "''${REQUIRES[$selection]:-}" ]]; then
        echo
        printf '%b\n' "''${BOLD}Dependencies:''${NC}"
        local deps
        deps=$(activate_dependencies "$selection")
        for dep in $deps; do
            [[ "$dep" == "$selection" ]] && continue
            local display_dep_name
            display_dep_name=$(get_display_name "$dep")
            echo "  - $display_dep_name"
        done
    else
        echo
        printf '%b\n' "''${BOLD}Dependencies:''${NC} None"
    fi
}
export -f generate_dependencies

check_script_execution "CORE_DIR" "generate_preview"
''
