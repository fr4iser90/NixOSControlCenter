#!/usr/bin/env bash

# Import alle Prompt-Module
source "$SCRIPT_DIR/ui/prompts/common.sh"
source "$SCRIPT_DIR/ui/prompts/setup-mode.sh"
source "$SCRIPT_DIR/ui/prompts/setup-options.sh"

# Import Formatting
source "$SCRIPT_DIR/ui/prompts/formatting/setup-formatting.sh"
source "$SCRIPT_DIR/ui/prompts/formatting/setup-preview.sh"
source "$SCRIPT_DIR/ui/prompts/formatting/setup-tree.sh"

# Import Rules
source "$SCRIPT_DIR/ui/prompts/rules/setup-rules.sh"

# Import Descriptions
source "$SCRIPT_DIR/ui/prompts/descriptions/setup-descriptions.sh"

# Import Validation
source "$SCRIPT_DIR/ui/prompts/validation/validate-mode.sh"

# Haupt-Prompt-Funktion
show_prompts() {
    log_section "Setup Configuration"
    
    # Setup Mode
    select_setup_mode
    
    # System Options
    configure_system_options
    
    # Validate Configuration
    validate_setup_mode
    
    # Show Preview
    show_setup_preview
}

# Export functions
export -f show_prompts