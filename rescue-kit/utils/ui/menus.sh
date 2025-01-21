#!/usr/bin/env bash

# Source UI functions
source "$(dirname "${BASH_SOURCE[0]}")/base.sh"
source "$(dirname "${BASH_SOURCE[0]}")/display.sh"

# Menu configuration
MENU_OPTION_COLOR=$UI_COLOR_PRIMARY
MENU_SELECTED_COLOR=$UI_COLOR_SUCCESS
MENU_HEADER_COLOR=$UI_COLOR_PRIMARY
MENU_FOOTER_COLOR=$UI_COLOR_WARNING

# Display menu and get selection
show_menu() {
  local title=$1
  local options=("${@:2}")
  local selected=0
  local options_count=${#options[@]}
  
  while true; do
    # Clear and display menu
    init_ui
    center_text "$title"
    echo ""
    
    # Display menu options
    for i in "${!options[@]}"; do
      if [ $i -eq $selected ]; then
        echo -e "${UI_SPACER}${MENU_SELECTED_COLOR}❯ ${options[$i]}${UI_COLOR_FG}"
      else
        echo -e "${UI_SPACER}${MENU_OPTION_COLOR}  ${options[$i]}${UI_COLOR_FG}"
      fi
    done
    
    # Display footer
    echo -e "\n${UI_SPACER}${MENU_FOOTER_COLOR}↑/↓: Navigate  ↵: Select${UI_COLOR_FG}"
    
    # Get user input
    read -rsn1 input
    case $input in
      # Up arrow
      $'\x1b')
        read -rsn1 -t 0.1 input
        if [[ $input == "[" ]]; then
          read -rsn1 -t 0.1 input
          if [[ $input == "A" ]]; then
            selected=$(( (selected - 1 + options_count) % options_count ))
          fi
        fi
        ;;
      # Down arrow
      $'\x1b')
        read -rsn1 -t 0.1 input
        if [[ $input == "[" ]]; then
          read -rsn1 -t 0.1 input
          if [[ $input == "B" ]]; then
            selected=$(( (selected + 1) % options_count ))
          fi
        fi
        ;;
      # Enter key
      "")
        break
        ;;
    esac
  done
  
  cleanup_ui
  return $selected
}

# Display confirmation dialog
confirm_action() {
  local prompt=$1
  local options=("Yes" "No")
  
  show_menu "$prompt" "${options[@]}"
  local choice=$?
  
  return $choice
}

# Display multi-select menu
multi_select_menu() {
  local title=$1
  local options=("${@:2}")
  local selected=()
  local options_count=${#options[@]}
  local current=0
  
  # Initialize selected array
  for ((i=0; i<options_count; i++)); do
    selected[$i]=0
  done
  
  while true; do
    # Clear and display menu
    init_ui
    center_text "$title"
    echo ""
    
    # Display menu options with selection status
    for i in "${!options[@]}"; do
      local checkbox=" "
      if [ ${selected[$i]} -eq 1 ]; then
        checkbox="${MENU_SELECTED_COLOR}✔${UI_COLOR_FG}"
      fi
      
      if [ $i -eq $current ]; then
        echo -e "${UI_SPACER}${MENU_SELECTED_COLOR}❯ ${checkbox} ${options[$i]}${UI_COLOR_FG}"
      else
        echo -e "${UI_SPACER}${MENU_OPTION_COLOR}  ${checkbox} ${options[$i]}${UI_COLOR_FG}"
      fi
    done
    
    # Display footer
    echo -e "\n${UI_SPACER}${MENU_FOOTER_COLOR}↑/↓: Navigate  Space: Toggle  ↵: Confirm${UI_COLOR_FG}"
    
    # Get user input
    read -rsn1 input
    case $input in
      # Up arrow
      $'\x1b')
        read -rsn1 -t 0.1 input
        if [[ $input == "[" ]]; then
          read -rsn1 -t 0.1 input
          if [[ $input == "A" ]]; then
            current=$(( (current - 1 + options_count) % options_count ))
          fi
        fi
        ;;
      # Down arrow
      $'\x1b')
        read -rsn1 -t 0.1 input
        if [[ $input == "[" ]]; then
          read -rsn1 -t 0.1 input
          if [[ $input == "B" ]]; then
            current=$(( (current + 1) % options_count ))
          fi
        fi
        ;;
      # Space bar
      " ")
        selected[$current]=$((1 - selected[$current]))
        ;;
      # Enter key
      "")
        break
        ;;
    esac
  done
  
  cleanup_ui
  
  # Return selected indices
  local result=()
  for i in "${!selected[@]}"; do
    if [ ${selected[$i]} -eq 1 ]; then
      result+=("$i")
    fi
  done
  
  echo "${result[@]}"
}
