#!/usr/bin/env bash

# UI Constants
UI_WIDTH=80
UI_PADDING=2
UI_COLOR_BG="\e[48;5;235m"  # Dark gray background
UI_COLOR_FG="\e[38;5;255m"  # White text
UI_COLOR_PRIMARY="\e[38;5;39m"  # Bright blue
UI_COLOR_SECONDARY="\e[38;5;129m"  # Purple
UI_COLOR_THIRD="\e[38;5;51m"  # Cyan
UI_COLOR_SUCCESS="\e[38;5;40m"  # Green
UI_COLOR_WARNING="\e[38;5;208m"  # Orange
UI_COLOR_ERROR="\e[38;5;196m"  # Red
UI_COLOR_RESET="\e[0m"

# Additional color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# UI Elements
UI_LINE="$(printf '%*s' "$UI_WIDTH" '' | tr ' ' '=')"
UI_SPACER="$(printf '%*s' "$UI_PADDING" '')"

# Initialize UI
init_ui() {
  clear
  printf "%b" "$UI_COLOR_BG$UI_COLOR_FG"
}

# Cleanup UI
cleanup_ui() {
  printf "%b" "$UI_COLOR_RESET"
  clear
}

# Print centered text
center_text() {
  local text=$1
  local text_length=${#text}
  local padding=$(( (UI_WIDTH - text_length) / 2 ))
  printf "%*s%b%s%b%*s\n" $padding "" "$UI_COLOR_PRIMARY" "$text" "$UI_COLOR_FG" $padding ""
}



# Print status message
status_message() {
  local type=$1
  local message=$2
  
  case $type in
    success) local color=$UI_COLOR_SUCCESS ;;
    warning) local color=$UI_COLOR_WARNING ;;
    error) local color=$UI_COLOR_ERROR ;;
    *) local color=$UI_COLOR_FG ;;
  esac
  
  echo -e "${UI_SPACER}${color}${message}${UI_COLOR_FG}"
}
