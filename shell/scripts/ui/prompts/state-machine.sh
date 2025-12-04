#!/usr/bin/env bash

# ============================================================================
# State Machine for Interactive Prompts with ESC Back Navigation
# ============================================================================
# 
# This module provides a centralized state machine for managing multi-step
# interactive prompts with ESC-based back navigation (Double ESC pattern).
#
# Features:
# - Double ESC pattern: First ESC = "Go back?", Second ESC = "Exit completely"
# - Navigation stack tracking
# - Reusable across all setup prompts
# - Modular and extensible
#
# ============================================================================

# State Machine States
declare -g STATE_NORMAL="normal"
declare -g STATE_ESC_ONCE="esc_once"
declare -g STATE_EXIT="exit"
declare -g STATE_BACK="back"

# Navigation Stack (stores navigation history)
declare -ga NAVIGATION_STACK=()

# Current State
declare -g CURRENT_STATE="$STATE_NORMAL"

# ============================================================================
# Core State Machine Functions
# ============================================================================

# Initialize state machine
init_state_machine() {
    NAVIGATION_STACK=()
    CURRENT_STATE="$STATE_NORMAL"
}

# Push current step to navigation stack
push_navigation() {
    local step_name="$1"
    local step_data="${2:-}"
    NAVIGATION_STACK+=("$step_name:$step_data")
}

# Pop last step from navigation stack (go back)
pop_navigation() {
    if [[ ${#NAVIGATION_STACK[@]} -gt 0 ]]; then
        unset 'NAVIGATION_STACK[-1]'
        return 0
    fi
    return 1
}

# Get current navigation step
get_current_step() {
    if [[ ${#NAVIGATION_STACK[@]} -gt 0 ]]; then
        echo "${NAVIGATION_STACK[-1]}"
    else
        echo ""
    fi
}

# Check if we're at the first step
is_first_step() {
    [[ ${#NAVIGATION_STACK[@]} -eq 0 ]]
}

# ============================================================================
# fzf Prompt with Double ESC Handling
# ============================================================================

# Show fzf prompt with double ESC pattern
# Usage: fzf_with_back <options_array> <header_text> <preview_script> [additional_fzf_args]
# Returns: Selected value or special codes: "BACK" or "EXIT"
fzf_with_back() {
    local options_array_name="$1"
    local header_text="$2"
    local preview_script="${3:-}"
    shift 3
    local additional_fzf_args=("$@")
    
    # Get options array
    local -n options_array="$options_array_name"
    
    # Build fzf options
    local fzf_opts=(
        --expect=esc
        --header="$header_text"
    )
    
    # Add preview if provided
    if [[ -n "$preview_script" ]]; then
        fzf_opts+=(--preview "$preview_script {}")
        fzf_opts+=(--preview-window="right:50%:wrap")
    fi
    
    # Add standard bindings
    fzf_opts+=(
        --bind 'space:accept'
        --pointer="▶"
        --marker="✓"
    )
    
    # Add any additional fzf args
    fzf_opts+=("${additional_fzf_args[@]}")
    
    # State machine loop
    local esc_state="$STATE_NORMAL"
    local result
    
    while true; do
        # Update header based on ESC state
        local current_header="$header_text"
        if [[ "$esc_state" == "$STATE_ESC_ONCE" ]]; then
            current_header="Go back? (Press ESC again to exit completely)"
        fi
        
        # Update fzf header
        fzf_opts[1]="--header=$current_header"
        
        # Run fzf
        result=$(printf "%s\n" "${options_array[@]}" | fzf "${fzf_opts[@]}") || {
            # fzf exited (user cancelled or ESC)
            if [[ "$esc_state" == "$STATE_ESC_ONCE" ]]; then
                # Second ESC → exit completely
                echo "EXIT"
                return 1
            else
                # Normal exit (Ctrl+C or other) → exit completely
                echo "EXIT"
                return 1
            fi
        }
        
        # Parse fzf result (format: KEY\nSELECTION)
        local key=$(echo "$result" | head -1)
        local choice=$(echo "$result" | tail -1)
        
        # Handle ESC key
        if [[ "$key" == "esc" ]]; then
            if [[ "$esc_state" == "$STATE_NORMAL" ]]; then
                # First ESC → show prompt, wait for second
                esc_state="$STATE_ESC_ONCE"
                continue
            elif [[ "$esc_state" == "$STATE_ESC_ONCE" ]]; then
                # Second ESC → exit completely
                echo "EXIT"
                return 1
            fi
        else
            # Valid selection made
            echo "$choice"
            return 0
        fi
    done
}

# Show multi-select fzf prompt with double ESC pattern
# Usage: fzf_multi_with_back <options_array> <header_text> <preview_script> [additional_fzf_args]
# Returns: Selected values (newline-separated) or special codes: "BACK" or "EXIT"
fzf_multi_with_back() {
    local options_array_name="$1"
    local header_text="$2"
    local preview_script="${3:-}"
    shift 3
    local additional_fzf_args=("$@")
    
    # Get options array
    local -n options_array="$options_array_name"
    
    # Build fzf options
    local fzf_opts=(
        --multi
        --expect=esc
        --header="$header_text"
    )
    
    # Add preview if provided
    if [[ -n "$preview_script" ]]; then
        fzf_opts+=(--preview "$preview_script {}")
        fzf_opts+=(--preview-window="right:50%:wrap")
    fi
    
    # Add standard bindings
    fzf_opts+=(
        --bind 'tab:toggle,space:toggle,ctrl-a:toggle-all'
        --pointer="▶"
        --marker="✓"
    )
    
    # Add any additional fzf args
    fzf_opts+=("${additional_fzf_args[@]}")
    
    # State machine loop
    local esc_state="$STATE_NORMAL"
    local result
    
    while true; do
        # Update header based on ESC state
        local current_header="$header_text"
        if [[ "$esc_state" == "$STATE_ESC_ONCE" ]]; then
            current_header="Go back? (Press ESC again to exit completely)"
        fi
        
        # Update fzf header
        fzf_opts[2]="--header=$current_header"
        
        # Run fzf
        result=$(printf "%s\n" "${options_array[@]}" | fzf "${fzf_opts[@]}") || {
            # fzf exited (user cancelled or ESC)
            if [[ "$esc_state" == "$STATE_ESC_ONCE" ]]; then
                # Second ESC → exit completely
                echo "EXIT"
                return 1
            else
                # Normal exit (Ctrl+C or other) → exit completely
                echo "EXIT"
                return 1
            fi
        }
        
        # Parse fzf result (format: KEY\nSELECTION1\nSELECTION2\n...)
        local key=$(echo "$result" | head -1)
        local choices=$(echo "$result" | tail -n +2)
        
        # Handle ESC key
        if [[ "$key" == "esc" ]]; then
            if [[ "$esc_state" == "$STATE_NORMAL" ]]; then
                # First ESC → show prompt, wait for second
                esc_state="$STATE_ESC_ONCE"
                continue
            elif [[ "$esc_state" == "$STATE_ESC_ONCE" ]]; then
                # Second ESC → exit completely
                echo "EXIT"
                return 1
            fi
        else
            # Valid selection made
            echo "$choices"
            return 0
        fi
    done
}

# ============================================================================
# Navigation Helper Functions
# ============================================================================

# Navigate back one step
navigate_back() {
    if pop_navigation; then
        echo "BACK"
        return 0
    else
        # Already at first step → exit completely
        echo "EXIT"
        return 1
    fi
}

# Check if result is a navigation command
is_navigation_command() {
    local result="$1"
    [[ "$result" == "BACK" || "$result" == "EXIT" ]]
}

# ============================================================================
# High-Level Prompt Functions
# ============================================================================

# Show single-select prompt with navigation
# Returns: Selected value, "BACK", or "EXIT"
prompt_select() {
    local step_name="$1"
    local options_array_name="$2"
    local header_text="$3"
    local preview_script="${4:-}"
    shift 4
    local additional_fzf_args=("$@")
    
    # Push current step to navigation stack
    push_navigation "$step_name" ""
    
    # Show prompt
    local result
    result=$(fzf_with_back "$options_array_name" "$header_text" "$preview_script" "${additional_fzf_args[@]}")
    local exit_code=$?
    
    # Handle navigation commands
    if [[ "$result" == "EXIT" ]]; then
        # Check if we're at first step
        if is_first_step; then
            return 1  # Exit completely
        else
            # Go back one step
            pop_navigation
            echo "BACK"
            return 2  # Special return code for "back"
        fi
    fi
    
    # Valid selection
    echo "$result"
    return 0
}

# Show multi-select prompt with navigation
# Returns: Selected values (newline-separated), "BACK", or "EXIT"
prompt_multi_select() {
    local step_name="$1"
    local options_array_name="$2"
    local header_text="$3"
    local preview_script="${4:-}"
    shift 4
    local additional_fzf_args=("$@")
    
    # Push current step to navigation stack
    push_navigation "$step_name" ""
    
    # Show prompt
    local result
    result=$(fzf_multi_with_back "$options_array_name" "$header_text" "$preview_script" "${additional_fzf_args[@]}")
    local exit_code=$?
    
    # Handle navigation commands
    if [[ "$result" == "EXIT" ]]; then
        # Check if we're at first step
        if is_first_step; then
            return 1  # Exit completely
        else
            # Go back one step
            pop_navigation
            echo "BACK"
            return 2  # Special return code for "back"
        fi
    fi
    
    # Valid selection
    echo "$result"
    return 0
}

# ============================================================================
# Export Functions
# ============================================================================

export -f init_state_machine
export -f push_navigation
export -f pop_navigation
export -f get_current_step
export -f is_first_step
export -f fzf_with_back
export -f fzf_multi_with_back
export -f navigate_back
export -f is_navigation_command
export -f prompt_select
export -f prompt_multi_select

