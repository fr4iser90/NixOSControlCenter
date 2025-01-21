#!/usr/bin/env bash

# Source base UI functions
source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

# Prompt for menu selection
prompt_menu_selection() {
  local prompt_text=${1:-"Select an option"}
  local options=("${@:2}")
  local min=1
  local max=${#options[@]}
  
  # If no options provided, expect min/max as parameters
  if [ $# -eq 3 ] && [[ $2 =~ ^[0-9]+$ ]] && [[ $3 =~ ^[0-9]+$ ]]; then
    min=$2
    max=$3
  fi
  
  while true; do
    # Display prompt with options if provided
    echo -e "\n${UI_COLOR_THIRD}${prompt_text}${UI_COLOR_FG}"
    
    if [ ${#options[@]} -gt 0 ]; then
      for i in "${!options[@]}"; do
        echo -e "${UI_SPACER}$((i+1)). ${options[$i]}"
      done
    fi
    
    # Get user input
    echo -ne "\n${UI_COLOR_THIRD}Please enter your choice (${min}-${max}):${UI_COLOR_FG}"
    read -n 1 -r choice
    echo
    
    # Validate input
    if [[ $choice =~ ^[0-9]+$ ]] && (( choice >= min && choice <= max )); then
      echo "$choice"
      return 0
    fi
    
    # Invalid selection
    echo -e "${UI_SPACER}${UI_COLOR_ERROR}Invalid selection! Please enter a number between ${min} and ${max}${UI_COLOR_FG}"
    sleep 1
  done
}

# Prompt for confirmation
confirm_action() {
  local prompt_text=${1:-"Are you sure?"}
  
  while true; do
    echo -ne "${UI_SPACER}${UI_COLOR_PRIMARY}${prompt_text} [y/n]: ${UI_COLOR_FG}"
    read -r confirm
    
    case $confirm in
      [Yy]* ) return 0 ;;
      [Nn]* ) return 1 ;;
      * ) echo -e "${UI_SPACER}${UI_COLOR_ERROR}Please answer yes or no${UI_COLOR_FG}" ;;
    esac
  done
}

# Prompt for text input
prompt_input() {
  local prompt_text=$1
  local default_value=${2:-""}
  local required=${3:-true}
  
  while true; do
    echo -ne "${UI_SPACER}${UI_COLOR_PRIMARY}${prompt_text}"
    
    if [ -n "$default_value" ]; then
      echo -ne " [${UI_COLOR_SECONDARY}${default_value}${UI_COLOR_PRIMARY}]"
    fi
    
    echo -ne ": ${UI_COLOR_FG}"
    read -r input
    
    # Use default if empty
    if [ -z "$input" ] && [ -n "$default_value" ]; then
      input="$default_value"
    fi
    
    # Validate required input
    if $required && [ -z "$input" ]; then
      echo -e "${UI_SPACER}${UI_COLOR_ERROR}Input is required${UI_COLOR_FG}"
      continue
    fi
    
    echo "$input"
    return 0
  done
}

# Prompt for password input
prompt_password() {
  local prompt_text=${1:-"Enter password"}
  
  while true; do
    echo -ne "${UI_SPACER}${UI_COLOR_PRIMARY}${prompt_text}: ${UI_COLOR_FG}"
    read -rs password
    echo
    
    if [ -z "$password" ]; then
      echo -e "${UI_SPACER}${UI_COLOR_ERROR}Password cannot be empty${UI_COLOR_FG}"
      continue
    fi
    
    echo -ne "${UI_SPACER}${UI_COLOR_PRIMARY}Confirm password: ${UI_COLOR_FG}"
    read -rs confirm_password
    echo
    
    if [ "$password" != "$confirm_password" ]; then
      echo -e "${UI_SPACER}${UI_COLOR_ERROR}Passwords do not match${UI_COLOR_FG}"
      continue
    fi
    
    echo "$password"
    return 0
  done
}

# Prompt to continue
prompt_continue() {
  read -n 1 -s
  echo
}
