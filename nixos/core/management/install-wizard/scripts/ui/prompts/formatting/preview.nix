# FZF preview — colors from cli-formatter palette (colors.sh).
{ pkgs, getModuleApi ? null, ... }:
pkgs.writeText "preview.sh" ''
#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
# Prefer install-wizard LIB_DIR colors (cli-formatter SSOT)
if [[ -n "''${LIB_DIR:-}" && -f "$LIB_DIR/colors.sh" ]]; then
  # shellcheck disable=SC1091
  source "$LIB_DIR/colors.sh"
elif [[ -z "''${COLORS_IMPORTED:-}" ]]; then
  # Colors should come from LIB_DIR/colors.sh (cli-formatter); plain fallback
  export BLUE= BOLD= NC=
fi

source "$SCRIPT_DIR/../descriptions/setup-descriptions.sh"
source "$SCRIPT_DIR/../setup-options.sh"

selection="$1"

clean_selection=$(echo "$selection" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    -e 's/^\* //' -e 's/^\*//' \
    -e 's/📦 //' -e 's/🔧 //' -e 's/⚙️  //' \
    -e 's/📁 //' -e 's/📋 //' -e 's/🔄 //' \
    -e 's/🖥️  //' -e 's/🤖 //')

clean_selection=$(echo "$clean_selection" | sed 's/^\[.*\] //')
clean_selection=$(echo "$clean_selection" | tr '[:upper:]' '[:lower:]')

if [[ -z "''${SETUP_DESCRIPTIONS[$clean_selection]:-}" ]] && [[ "$clean_selection" =~ " " ]]; then
    clean_selection_dashed=$(echo "$clean_selection" | sed 's/ /-/g')
    if [[ -n "''${SETUP_DESCRIPTIONS[$clean_selection_dashed]:-}" ]]; then
        clean_selection="$clean_selection_dashed"
    fi
fi

printf '%b\n' "''${BLUE}''${BOLD}''${selection}''${NC}"
echo "------------------------------------"

echo
if [[ -n "''${SETUP_DESCRIPTIONS[$clean_selection]:-}" ]]; then
    printf '%b\n' "''${SETUP_DESCRIPTIONS[$clean_selection]}"
else
    echo "No specific description available for \"$clean_selection\"."
fi

echo
printf '%b\n' "''${BOLD}Type:''${NC} ''${SETUP_TYPES[$clean_selection]:-Predefined Desktop Profile}"
printf '%b\n' "''${BOLD}Features:''${NC}"
features_text=''${SETUP_FEATURES[$clean_selection]:-"Development Environment|Common Applications|Personalized Settings|Dotfiles Integration"}
if [[ "$features_text" == "N/A" || -z "$features_text" ]]; then
    echo "  - No specific features listed."
else
    echo "$features_text" | tr '|' '\n' | sed 's/^/  - /'
fi

echo
printf '%b\n' "''${BOLD}Dependencies:''${NC} None"
''
