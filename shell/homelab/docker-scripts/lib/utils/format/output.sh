#!/bin/bash

# Print a formatted header
print_header() {
    local title="$1"
    local width=50
    local padding=$(( (width - ${#title}) / 2 ))
    
    echo
    printf "%${width}s\n" | tr ' ' '='
    printf "%${padding}s%s%${padding}s\n" "" "$title" ""
    printf "%${width}s\n" | tr ' ' '='
    echo
}

# Print status message with icon
print_status() {
    local message="$1"
    local status="${2:-info}"  # info, success, warning, error, input
    
    case "$status" in
        success)
            echo -e "${SUCCESS} ✓ $message"
            ;;
        warning)
            echo -e "${WARNING} ⚠ $message"
            ;;
        error)
            echo -e "${ERROR} ✗ $message"
            ;;
        input)
            echo -e "${PROMPT} ⌨ $message"  
            ;;
        *)
            echo -e "${INFO} ℹ $message"
            ;;
    esac
}

# Print data in table format
print_table() {
    local -n headers=$1
    local -n data=$2
    local num_cols=${#headers[@]}
    
    # Calculate column widths
    local -a widths
    for ((i=0; i<num_cols; i++)); do
        widths[i]=${#headers[i]}
        for row in "${data[@]}"; do
            local field=$(echo "$row" | cut -d'|' -f$((i+1)))
            if [ ${#field} -gt ${widths[i]} ]; then
                widths[i]=${#field}
            fi
        done
    done
    
    # Print headers
    for ((i=0; i<num_cols; i++)); do
        printf "${BLUE}%-${widths[i]}s${NC}" "${headers[i]}"
        if [ $i -lt $((num_cols-1)) ]; then
            printf " | "
        fi
    done
    echo
    
    # Print separator
    for ((i=0; i<num_cols; i++)); do
        printf "%${widths[i]}s" | tr ' ' '-'
        if [ $i -lt $((num_cols-1)) ]; then
            printf "-+-"
        fi
    done
    echo
    
    # Print data
    for row in "${data[@]}"; do
        local -a fields
        IFS='|' read -ra fields <<< "$row"
        for ((i=0; i<num_cols; i++)); do
            printf "%-${widths[i]}s" "${fields[i]}"
            if [ $i -lt $((num_cols-1)) ]; then
                printf " | "
            fi
        done
        echo
    done
}

# Show progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((percentage * width / 100))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' ' '
    printf "] %d%%" "$percentage"
    
    if [ "$current" -eq "$total" ]; then
        echo
    fi
}