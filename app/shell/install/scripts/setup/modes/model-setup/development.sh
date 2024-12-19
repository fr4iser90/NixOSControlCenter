#!/usr/bin/env bash

declare -A DEV_MODULES=(
    ["Game Development"]="Game development tools"
    ["Web Development"]="Web development stack"
)

select_dev_modules() {
    printf "%s\n" "${!DEV_MODULES[@]}" | fzf \
        --header="Select Development Modules" \
        --multi \
        --preview 'echo "${DEV_MODULES[$1]}"' \
        --prompt="Dev > "
}