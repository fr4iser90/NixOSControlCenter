#!/usr/bin/env bash
set -euo pipefail

# Source core components
source "$CORE_DIR/imports.sh"

# Tree structure constants
declare -r TREE_INDENT="  "
declare -r TREE_BRANCH="├─"
declare -r TREE_LAST="└─"
declare -r TREE_VERTICAL="│"

generate_tree() {
    log_debug "Generating setup tree"
    local -a tree=()
    
    # Add root level options
    add_root_options tree
    
    # Add child options
    add_desktop_branch tree
    add_server_branch tree
    
    # Output the tree
    printf '%s\n' "${tree[@]}"
    return 0
}

add_root_options() {
    local -n tree_ref=$1
    
    tree_ref+=("Desktop")
    tree_ref+=("Server")
    tree_ref+=("HomelabServer")
    tree_ref+=("Custom Setup")
}

add_desktop_branch() {
    local -n tree_ref=$1
    
    # Gaming Features
    tree_ref+=("$TREE_INDENT$TREE_BRANCH Gaming Features")
    tree_ref+=("$TREE_INDENT$TREE_VERTICAL  $TREE_BRANCH streaming")
    tree_ref+=("$TREE_INDENT$TREE_VERTICAL  $TREE_LAST emulation")
    
    # Development Features
    tree_ref+=("$TREE_INDENT$TREE_BRANCH Development Features")
    tree_ref+=("$TREE_INDENT$TREE_VERTICAL  $TREE_BRANCH web-dev")
    tree_ref+=("$TREE_INDENT$TREE_VERTICAL  $TREE_BRANCH game-dev")
    tree_ref+=("$TREE_INDENT$TREE_VERTICAL  $TREE_BRANCH python-dev")
    tree_ref+=("$TREE_INDENT$TREE_VERTICAL  $TREE_LAST system-dev")
    
    # Virtualization Features (Desktop)
    tree_ref+=("$TREE_INDENT$TREE_LAST Virtualization Features")
    tree_ref+=("$TREE_INDENT   $TREE_BRANCH qemu-vm")
    tree_ref+=("$TREE_INDENT   $TREE_LAST virt-manager")
}

add_server_branch() {
    local -n tree_ref=$1
    
    # Virtualization Features (Server)
    tree_ref+=("$TREE_INDENT$TREE_BRANCH Virtualization Features")
    tree_ref+=("$TREE_INDENT$TREE_VERTICAL  $TREE_BRANCH docker")
    tree_ref+=("$TREE_INDENT$TREE_VERTICAL  $TREE_BRANCH docker-rootless")
    tree_ref+=("$TREE_INDENT$TREE_VERTICAL  $TREE_LAST qemu-vm")
    
    # Server Features
    tree_ref+=("$TREE_INDENT$TREE_BRANCH Server Features")
    tree_ref+=("$TREE_INDENT$TREE_VERTICAL  $TREE_BRANCH database")
    tree_ref+=("$TREE_INDENT$TREE_VERTICAL  $TREE_BRANCH web-server")
    tree_ref+=("$TREE_INDENT$TREE_VERTICAL  $TREE_LAST mail-server")
}

# Check script execution
check_script_execution "CORE_DIR" "generate_tree"
