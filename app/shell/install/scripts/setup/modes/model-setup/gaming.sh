#!/usr/bin/env bash

declare -A GAMING_MODULES=(
    ["Streaming"]="Streaming tools (OBS, etc.)"
    ["Emulation"]="Retro gaming emulators"
)

select_gaming_modules() {
    printf "%s\n" "${!GAMING_MODULES[@]}" | fzf \
        --header="Select Gaming Modules" \
        --multi \
        --preview 'echo "${GAMING_MODULES[$1]}"' \
        --prompt="Gaming > "
}