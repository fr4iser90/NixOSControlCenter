#!/usr/bin/env bash

# Source UI components
source "$(dirname "${BASH_SOURCE[0]}")/ui/base.sh"
source "$(dirname "${BASH_SOURCE[0]}")/ui/prompts.sh"

# Menu Configuration
declare -A MENU_ITEMS
declare -A MENU_HANDLERS
CURRENT_MENU="main"
MENU_STACK=()

# Initialize menu system
init_menu() {
  MENU_ITEMS=()
  MENU_HANDLERS=()
  CURRENT_MENU="main"
  MENU_STACK=()
}

# Add menu item
add_menu_item() {
  local menu_name=$1
  local item_number=$2
  local item_label=$3
  local handler_function=$4
  
  MENU_ITEMS["${menu_name}_${item_number}_label"]=$item_label
  MENU_HANDLERS["${menu_name}_${item_number}"]=$handler_function
}

# Display menu
display_menu() {
  local menu_name=$1
  local title=$2
  local title_type=${3:-primary}
  
  clear
  if [[ "$title_type" == "primary" ]]; then
    center_text "$title"
  else
    echo -e "\n${UI_SPACER}${UI_COLOR_SECONDARY}${title}${UI_COLOR_FG}"
  fi
  echo -e "\n${UI_LINE}"
  
  # Get and display menu items in order
  local item_count=0
  for i in $(seq 1 100); do
    local label_key="${menu_name}_${i}_label"
    if [[ -n "${MENU_ITEMS[$label_key]:-}" ]]; then
      item_count=$((item_count + 1))
      echo -e "${UI_SPACER}${UI_COLOR_SECONDARY}${i}. ${MENU_ITEMS[$label_key]}${UI_COLOR_FG}"
    fi
  done
  
  # Add UI separator
  echo -e "${UI_LINE}"
  
  # Display prompt with proper spacing
  echo -e "\n${UI_COLOR_SECONDARY}Please enter your choice (1-${item_count}):${UI_COLOR_FG}"
}

# Handle menu selection
handle_menu_selection() {
  local menu_name=$1
  local choice=$2
  
  # Get total number of menu items
  local item_count=0
  for i in $(seq 1 100); do
    if [[ -n "${MENU_ITEMS[${menu_name}_${i}_label]:-}" ]]; then
      item_count=$((item_count + 1))
    fi
  done
  
  # Validate choice is a number
  if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    display_error "Invalid selection! Please enter a number between 1 and ${item_count}"
    sleep 1.5
    return
  fi
  
  # Convert choice to integer
  choice=$((choice))
  
  # Validate choice range
  if [ "$choice" -lt 1 ] || [ "$choice" -gt "$item_count" ]; then
    display_error "Invalid selection! Please enter a number between 1 and ${item_count}"
    sleep 1.5
    return
  fi
  
  # Execute handler if exists
  local handler=${MENU_HANDLERS["${menu_name}_${choice}"]}
  if [ -n "$handler" ] && type "$handler" &>/dev/null; then
    $handler
  else
    display_error "Missing handler for selection $choice"
    sleep 1.5
  fi
}

# Helper function to create standard menu
create_standard_menu() {
  local menu_name=$1
  local title=$2
  shift 2
  local items=("$@")
  
  init_menu
  # Store the menu title
  MENU_ITEMS["${menu_name}_title"]=$title
  
  for i in "${!items[@]}"; do
    # Convert menu item to handler name (lowercase with underscores)
    local handler_name=$(echo "${items[$i]}" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')"_handler"
    add_menu_item "$menu_name" $((i+1)) "${items[$i]}" "$handler_name"
  done
  
  CURRENT_MENU="$menu_name"
}

# Main menu loop
menu_loop() {
  local title_type=${1:-primary}
  while true; do
    local title="${MENU_ITEMS["${CURRENT_MENU}_title"]}"
    display_menu "$CURRENT_MENU" "${title:-$CURRENT_MENU}" "$title_type"
    read -p "Enter your choice: " choice
    handle_menu_selection "$CURRENT_MENU" "$choice"
  done
}

# Push current menu to stack and switch to new menu
push_menu() {
  MENU_STACK+=("$CURRENT_MENU")
  CURRENT_MENU=$1
}

# Pop menu from stack and return to previous menu
pop_menu() {
  if [ ${#MENU_STACK[@]} -gt 0 ]; then
    CURRENT_MENU=${MENU_STACK[-1]}
    unset 'MENU_STACK[${#MENU_STACK[@]}-1]'
    # Reinitialize menu items for the previous menu
    init_menu
    case $CURRENT_MENU in
      "main") create_main_menu ;;
      "sshd") sshd_menu ;;
      *) create_main_menu ;;
    esac
  else
    CURRENT_MENU="main"
    create_main_menu
  fi
}

# Handler for back to main menu
back_to_main_handler() {
  pop_menu
}
