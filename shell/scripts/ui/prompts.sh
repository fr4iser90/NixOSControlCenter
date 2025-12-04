#!/usr/bin/env bash

# This is the main script to orchestrate all UI prompts.

# --- Source All Necessary Prompt Components --- #

# 0. State Machine (must be loaded first - used by all prompts)
source "$DOCKER_SCRIPTS_DIR/ui/prompts/state-machine.sh"

# 1. Common utilities and base fzf options
source "$DOCKER_SCRIPTS_DIR/ui/prompts/common.sh"

# 2. Option definitions (get_internal_name, get_display_name, and option arrays)
source "$DOCKER_SCRIPTS_DIR/ui/prompts/setup-options.sh"

# 3. Descriptions and arrays for preview
source "$DOCKER_SCRIPTS_DIR/ui/prompts/descriptions/setup-descriptions.sh"

# 4. Rules for dependencies and conflicts
source "$DOCKER_SCRIPTS_DIR/ui/prompts/rules/setup-rules.sh"

# 5. Preview generation functions
source "$DOCKER_SCRIPTS_DIR/ui/prompts/formatting/setup-preview.sh"

# 6. Main selection logic for setup mode / profiles
source "$DOCKER_SCRIPTS_DIR/ui/prompts/setup-mode.sh"

# 7. Other formatting utilities
source "$DOCKER_SCRIPTS_DIR/ui/prompts/formatting/setup-formatting.sh"
source "$DOCKER_SCRIPTS_DIR/ui/prompts/formatting/setup-tree.sh"

# 8. Validation logic
source "$DOCKER_SCRIPTS_DIR/ui/prompts/validation/validate-mode.sh"

# --- Main Prompt Function --- #
show_prompts() {
    log_section "Setup Configuration"
    
    # Initialize state machine for navigation
    init_state_machine
    
    local selected_config
    selected_config=$(select_setup_mode)
    
    if [ -z "$selected_config" ]; then
        log_error "No configuration selected. Aborting setup."
        return 1
    fi

    log_info "Selected configuration: $selected_config"
    return 0
}

export -f show_prompts