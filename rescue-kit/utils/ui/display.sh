#!/usr/bin/env bash

# Source base UI functions
source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

# Display header with centered text and border
display_header() {
  local text=$1
  local width=$((UI_WIDTH - (UI_PADDING * 2)))
  local border=$(printf "%${width}s" "" | tr ' ' '=')
  
  echo -e "\n${UI_SPACER}${UI_COLOR_PRIMARY}${border}${UI_COLOR_FG}"
  echo -e "${UI_SPACER}${UI_COLOR_PRIMARY}$(printf "%*s" $(((${#text}+width)/2)) "$text")${UI_COLOR_FG}"
  echo -e "${UI_SPACER}${UI_COLOR_PRIMARY}${border}${UI_COLOR_FG}\n"
}

# Display menu options
display_menu_options() {
  local options=("$@")
  
  for i in "${!options[@]}"; do
    echo -e "${UI_SPACER}${UI_COLOR_SECONDARY}$((i+1)). ${options[$i]}${UI_COLOR_FG}"
  done
  echo ""
}

# Display success message
display_success() {
  local message=$1
  echo -e "${UI_SPACER}${UI_COLOR_SUCCESS}✓ ${message}${UI_COLOR_FG}"
}

# Display error message
display_error() {
  local message=$1
  echo -e "${UI_SPACER}${UI_COLOR_ERROR}✗ ${message}${UI_COLOR_FG}"
}

# Print formatted text block
text_block() {
  local text=$1
  local width=$((UI_WIDTH - (UI_PADDING * 2)))
  
  echo -e "${UI_SPACER}$(echo -e "$text" | fold -s -w $width)"
}

# Print key-value pair
key_value() {
  local key=$1
  local value=$2
  local key_width=20
  local value_width=$((UI_WIDTH - key_width - (UI_PADDING * 2)))
  
  printf "${UI_SPACER}${UI_COLOR_PRIMARY}%-${key_width}s${UI_COLOR_FG}%s\n" "$key" "$(echo "$value" | fold -s -w $value_width)"
}

# Print progress bar
progress_bar() {
  local current=$1
  local total=$2
  local label=${3:-""}
  local bar_width=$((UI_WIDTH - (UI_PADDING * 2) - 10))
  local progress=$((current * bar_width / total))
  
  # Build progress bar
  local bar="["
  bar+="$(printf '%*s' "$progress" '' | tr ' ' '█')"
  bar+="$(printf '%*s' "$((bar_width - progress))" '' | tr ' ' ' ')"
  bar+="]"
  
  # Add percentage
  local percent=$((current * 100 / total))
  bar+=" $(printf "%3d%%" "$percent")"
  
  # Print with label if provided
  if [ -n "$label" ]; then
    echo -e "${UI_SPACER}${label}"
  fi
  echo -e "${UI_SPACER}${bar}"
}

# Print table header with padding and dynamic column widths
table_header() {
  local columns=("$@")
  local total_columns=${#columns[@]}
  local available_width=$((UI_WIDTH - (UI_PADDING * 2) - (total_columns * 2)))
  local col_width=$((available_width / total_columns))
  
  # Print header line with padding
  echo -n "${UI_SPACER}"
  for col in "${columns[@]}"; do
    printf " %-${col_width}s " "$col"
  done
  echo ""
  
  # Print separator with padding
  echo -n "${UI_SPACER}"
  for col in "${columns[@]}"; do
    printf " %${col_width}s " "" | tr ' ' '─'
  done
  echo ""
}

# Print table row with padding and consistent column widths
table_row() {
  local columns=("$@")
  local total_columns=${#columns[@]}
  local available_width=$((UI_WIDTH - (UI_PADDING * 2) - (total_columns * 2)))
  local col_width=$((available_width / total_columns))
  
  echo -n "${UI_SPACER}"
  for col in "${columns[@]}"; do
    printf " %-${col_width}s " "$col"
  done
  echo ""
}



# Display help information
display_help() {
    display_header "NixOS Rescue Kit Help"
    
    text_block "This tool provides essential recovery and maintenance functions for NixOS systems. Use the menu options to:"
    
    key_value "System Checks" "Verify system health and configuration"
    key_value "Mount Partitions" "Prepare system for recovery"
    key_value "Backup System" "Create essential or full backups"
    key_value "Rebuild System" "Rebuild NixOS configuration"
    key_value "SSH Management" "Control remote access"
    
    echo -e "\n${UI_SPACER}${UI_COLOR_SECONDARY}Press any key to return to main menu${UI_COLOR_FG}"
}
