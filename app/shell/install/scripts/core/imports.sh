#!/usr/bin/env bash

# Ensure environment is initialized before proceeding
if [[ -z "${LIB_DIR:-}" ]]; then
    echo "Error: Environment not properly initialized"
    exit 1
fi

# Prevent multiple sourcing of this file
if [[ -n "${_IMPORTS_LOADED:-}" ]]; then
    return 0
fi
_IMPORTS_LOADED=1

# Source a file and handle errors
import_file() {
    local file=$1
    if ! source "$file"; then
        echo "Error: Failed to load $file"
        return 1
    fi
}

# Load mode-specific modules
load_mode_modules() {
    local mode=$1
    local mode_dir="$SETUP_DIR/modes/$mode"
    
    if [[ -d "$mode_dir" ]]; then
        # First load the main setup.sh
        if [[ -f "$mode_dir/setup.sh" ]]; then
            import_file "$mode_dir/setup.sh"
        fi
        
        # Then recursively load all other .sh files
        while IFS= read -r -d '' file; do
            # Skip the main setup.sh as it's already loaded
            [[ "$file" == */setup.sh ]] && continue
            
            import_file "$file"
        done < <(find "$mode_dir" -type f -name "*.sh" -print0)
    fi
}

# 1. Core Dependencies
import_file "$LIB_DIR/colors.sh"     
import_file "$LIB_DIR/utils.sh"      
import_file "$LIB_DIR/logging.sh"    

# 2. System Information Collection
import_file "$CHECKS_DIR/hardware/cpu.sh"      
import_file "$CHECKS_DIR/hardware/gpu.sh"      
import_file "$CHECKS_DIR/system/hosting.sh"    
import_file "$CHECKS_DIR/system/locale.sh"     
import_file "$CHECKS_DIR/system/users.sh"      
import_file "$CHECKS_DIR/system/bootloader.sh" 

# 3. Security Components
import_file "$LIB_DIR/security/password-check.sh"    
import_file "$LIB_DIR/security/setup-permissions.sh" 

# 4. System Dependencies
import_file "$LIB_DIR/system/dependencies.sh"

# 5. User Interface Components
import_file "$PROMPTS_DIR/common.sh"                        
import_file "$PROMPTS_DIR/descriptions/setup-descriptions.sh" 
import_file "$PROMPTS_DIR/setup-options.sh"                
import_file "$PROMPTS_DIR/setup-rules.sh"                  
import_file "$PROMPTS_DIR/validate-mode.sh"                
import_file "$PROMPTS_DIR/setup-mode.sh"                   
import_file "$PROMPTS_DIR/formatting/setup-formatting.sh"    
import_file "$PROMPTS_DIR/formatting/setup-preview.sh"      
import_file "$PROMPTS_DIR/formatting/setup-tree.sh"         

# 6. Core System Components
import_file "$CORE_DIR/deploy-build.sh"                    
import_file "$SETUP_DIR/config/secrets-setup.sh"           

# 7. Data Collection and Configuration
import_file "$SETUP_DIR/config/data-collection/collect-system-data.sh"  
import_file "$SETUP_DIR/config/data-collection/collect-server-data.sh"  

# Load modules for each mode
load_mode_modules "desktop"
load_mode_modules "server"
load_mode_modules "homelab"
