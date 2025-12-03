#!/usr/bin/env bash

# Source necessary files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../descriptions/setup-descriptions.sh"
source "$SCRIPT_DIR/../setup-options.sh"

selection="$1"

# Clean up selection string (handle emojis and special characters)
clean_selection=$(echo "$selection" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    -e 's/📦 //' -e 's/🔧 //' -e 's/⚙️  //' \
    -e 's/📁 //' -e 's/📋 //' -e 's/🔄 //' \
    -e 's/🖥️  //' -e 's/🤖 //' \
    -e 's/ /-/g' | tr '[:upper:]' '[:lower:]')

# Header
echo -e "\\033[1;34m${selection}\\033[0m"
echo "------------------------------------"

# Description
echo
if [[ -n "${SETUP_DESCRIPTIONS[$clean_selection]:-}" ]]; then
    echo -e "${SETUP_DESCRIPTIONS[$clean_selection]}"
else
    echo "No specific description available for \"$clean_selection\"."
fi

# Type and Features
echo
echo -e "\\033[1mType:\\033[0m ${SETUP_TYPES[$clean_selection]:-Predefined Desktop Profile}"
echo -e "\\033[1mFeatures:\\033[0m"
features_text=${SETUP_FEATURES[$clean_selection]:-"Development Environment|Common Applications|Personalized Settings|Dotfiles Integration"}
if [[ "$features_text" == "N/A" || -z "$features_text" ]]; then
    echo "  - No specific features listed."
else
    echo "$features_text" | tr '|' '\n' | sed 's/^/  - /'
fi

# Dependencies
echo
echo -e "\\033[1mDependencies:\\033[0m None" 