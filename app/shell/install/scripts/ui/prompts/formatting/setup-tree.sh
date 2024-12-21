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
    
    # Gaming branch
    tree_ref+=("$TREE_INDENT$TREE_BRANCH Gaming")
    tree_ref+=("$TREE_INDENT$TREE_VERTICAL  $TREE_BRANCH Gaming-Streaming")
    tree_ref+=("$TREE_INDENT$TREE_VERTICAL  $TREE_LAST Gaming-Emulation")
    
    # Development branch
    tree_ref+=("$TREE_INDENT$TREE_LAST Development")
    tree_ref+=("$TREE_INDENT   $TREE_BRANCH Development-Web")
    tree_ref+=("$TREE_INDENT   $TREE_LAST Development-Game")
    tree_ref+=("$TREE_INDENT   $TREE_LAST Development-Virtualization")
}

add_server_branch() {
    local -n tree_ref=$1
    
    # Server options
    tree_ref+=("$TREE_INDENT$TREE_BRANCH Docker")
    tree_ref+=("$TREE_INDENT$TREE_LAST Database")
}

# Check script execution
check_script_execution "CORE_DIR" "generate_tree"