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
  
  clear
  center_text "$title"
  echo -e "\n${UI_LINE}"
  
  # Get and display menu items in order
  local item_count=0
  for i in $(seq 1 100); do
    local label_key="${menu_name}_${i}_label"
    if [[ -n "${MENU_ITEMS[$label_key]:-}" ]]; then
      item_count=$((item_count + 1))
      echo -e "${UI_SPACER}${i}. ${MENU_ITEMS[$label_key]}"
    fi
  done
  
  # Add UI separator
  echo -e "${UI_LINE}"
  
  # Display prompt with proper spacing
  echo -e "\n${UI_COLOR_THIRD}Please enter your choice (1-${item_count}):${UI_COLOR_FG}"
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
  for i in "${!items[@]}"; do
    # Convert menu item to handler name (lowercase with underscores)
    local handler_name=$(echo "${items[$i]}" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')"_handler"
    add_menu_item "$menu_name" $((i+1)) "${items[$i]}" "$handler_name"
  done
  
  CURRENT_MENU="$menu_name"
}

# Menu handler functions
system_checks_handler() {
    if [ -f "$rescue_kit_root_dir/modules/checks/menu.sh" ]; then
        source "$rescue_kit_root_dir/modules/checks/menu.sh"
        checks_menu
    else
        display_error "System Checks module not found!"
        sleep 1.5
    fi
}

partition_management_handler() {
    if [ -f "$rescue_kit_root_dir/modules/mount/menu.sh" ]; then
        source "$rescue_kit_root_dir/modules/mount/menu.sh"
        mount_menu
    else
        display_error "Partition Management module not found!"
        sleep 1.5
    fi
}

backup_management_handler() {
    if [ -f "$rescue_kit_root_dir/modules/backup/menu.sh" ]; then
        source "$rescue_kit_root_dir/modules/backup/menu.sh"
        backup_menu
    else
        display_error "Backup Management module not found!"
        sleep 1.5
    fi
}

system_repair_handler() {
    if [ -f "$rescue_kit_root_dir/modules/repair/menu.sh" ]; then
        source "$rescue_kit_root_dir/modules/repair/menu.sh"
        repair_menu
    else
        display_error "System Repair module not found!"
        sleep 1.5
    fi
}

rebuild_system_handler() {
    if [ -f "$rescue_kit_root_dir/modules/rebuild/menu.sh" ]; then
        source "$rescue_kit_root_dir/modules/rebuild/menu.sh"
        rebuild_menu
    else
        display_error "Rebuild System module not found!"
        sleep 1.5
    fi
}

ssh_management_handler() {
    if [ -f "$rescue_kit_root_dir/modules/sshd/menu.sh" ]; then
        source "$rescue_kit_root_dir/modules/sshd/menu.sh"
        sshd_menu
    else
        display_error "SSH Management module not found!"
        sleep 1.5
    fi
}

help_handler() {
    display_help
    prompt_continue
}

exit_handler() {
    if confirm_action "Are you sure you want to exit?"; then
        display_success "Exiting..."
        exit 0
    fi
}

# Main menu loop
menu_loop() {
  while true; do
    display_menu "$CURRENT_MENU" "Main Menu"
    read -p "Enter your choice: " choice
    handle_menu_selection "$CURRENT_MENU" "$choice"
  done
}
