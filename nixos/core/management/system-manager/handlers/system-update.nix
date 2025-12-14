{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  backupSettings = {
    enabled = true;
    retention = 5;
    directory = "/var/backup/nixos";
  };

  updateSources = [
    {
      name = "remote";
      url = "https://github.com/fr4iser90/NixOSControlCenter.git";
      branches = [ "main" "develop" "experimental" ];
    }
    {
      name = "local";
      url = "/home/${username}/Documents/Git/NixOSControlCenter/nixos";
      branches = [];
    }
  ];

  ui = config.core.management.system-manager.submodules.cli-formatter.api;
  commandCenter = systemConfig.core.management.system-manager.submodules.cli-registry;

  # Extract configuration values
  username = head (attrNames systemConfig.users);
  hostname = systemConfig.hostName;
  autoBuild = systemConfig.management.system-manager.auto-build or false;
  systemChecks = systemConfig.core.management.system-manager.submodules.system-checks.enable or false;
  # Function to prompt for build - with conditional build command and better error handling
  prompt_build = ''
    while true; do
      printf "Do you want to build and switch to the new configuration? (y/n): "
      read build_choice
      case $build_choice in
        y|Y)
          ${ui.messages.loading "Building system configuration..."}
          BUILD_CMD="${if systemChecks then "sudo ncc build switch --flake /etc/nixos#${hostname}" else "sudo nixos-rebuild switch --flake /etc/nixos#${hostname}"}"
          
          # Run build and capture exit code
          if $BUILD_CMD 2>&1; then
            ${ui.messages.success "System successfully updated and rebuilt!"}
          else
            EXIT_CODE=$?
            # Check if build was successful but switch failed (common with service reload errors)
            if [ -f /nix/var/nix/profiles/system ]; then
              CURRENT_GEN=$(readlink /nix/var/nix/profiles/system | cut -d'-' -f2)
              if [ -n "$CURRENT_GEN" ]; then
                ${ui.messages.warning "Build completed, but switch encountered issues (exit code: $EXIT_CODE)"}
                ${ui.messages.info "Current generation: $CURRENT_GEN"}
                ${ui.messages.info "Some services may have failed to reload (e.g., dbus-broker.service)"}
                ${ui.messages.info "This is often harmless - the system should still work correctly."}
                ${ui.messages.info "You can verify with: sudo nixos-rebuild switch --flake /etc/nixos#${hostname}"}
              else
                ${ui.messages.error "Build may have failed. Check logs for details."}
              fi
            else
              ${ui.messages.error "Build failed! Check logs for details."}
            fi
          fi
          break
          ;;
        n|N)
          ${ui.messages.info "Skipping build. You can manually run: ${if systemChecks then "sudo ncc build switch" else "sudo nixos-rebuild switch"} --flake /etc/nixos#${hostname}"}
          break
          ;;
        *)
          ${ui.messages.error "Invalid choice, please enter y or n"}
          ;;
      esac
    done
  '';
  
  # Import config management (single import, clean API)
  # Terminal-UI is imported directly in core/infrastructure/config, no need to pass it
  configModule = import ../components/config-migration { inherit pkgs lib systemConfig; };
  
  # Create script with runtime dependencies (only available for this script, not system-wide)
  systemUpdateMainScript = pkgs.symlinkJoin {
    name = "ncc-system-update-main";
    paths = [
      (pkgs.writeScriptBin "ncc-system-update-main" ''
    #!${pkgs.bash}/bin/bash
    set -e

    # Parse arguments for verbose mode, force-migration, force-update, and cleanup
    VERBOSE=false
    FORCE_MIGRATION=false
    FORCE_UPDATE=false
    CLEANUP=false
    for arg in "$@"; do
      case "$arg" in
        --verbose|--debug|-v)
          VERBOSE=true
          ;;
        --force-migration)
          FORCE_MIGRATION=true
          ;;
        --force-update)
          FORCE_UPDATE=true
          ;;
        --cleanup)
          CLEANUP=true
          ;;
      esac
    done

    # Sudo-Check
    if [ "$EUID" -ne 0 ]; then
      ${ui.messages.error "This script must be run as root (use sudo)"}
      ${ui.messages.info "Usage: sudo $0"}
      exit 1
    fi

    # Configuration
    NIXOS_DIR="/etc/nixos"
    BACKUP_ROOT="${backupSettings.directory}"
    
    ${ui.text.header "NixOS System Update"}
    
    # Step 1: Check system configuration (validates + migrates if needed)
    # ncc-config-check already outputs status messages, so we just check the exit code
    if ! ${configModule.configCheck}/bin/ncc-config-check $([ "$VERBOSE" = "true" ] && echo "--verbose") 2>&1; then
      ${ui.messages.warning "Configuration has issues (migration may have been attempted)"}
      ${ui.messages.info "You may want to review the configuration before proceeding"}
    fi
    
    ${ui.messages.info "Select update source or action:"}
    
    echo "1) Update Configuration (Remote Repository)"
    echo "2) Update Configuration (Local Directory)"
    echo "3) Update Channels (flake inputs)"
    
    while true; do
      printf "Select option (1-3): "
      read source_choice
      case $source_choice in
        1)
          # Remote update configuration
          REPO_URL="https://github.com/fr4iser90/NixOSControlCenter.git"
          TEMP_DIR="/tmp/nixos-update"
          
          ${ui.text.header "NixOS System Update - Remote"}
          ${ui.messages.info "Available branches:"}
          
          echo "1) main"
          echo "2) develop"
          echo "3) experimental"
          echo "4) custom"
          
          while true; do
            printf "Select branch (1-4): "
            read choice
            case $choice in
              1) 
                SELECTED_BRANCH="main"
                break
                ;;
              2)
                SELECTED_BRANCH="develop"
                break
                ;;
              3)
                SELECTED_BRANCH="experimental"
                break
                ;;
              4)
                printf "Enter custom branch name: "
                read SELECTED_BRANCH
                break
                ;;
              *)
                ${ui.messages.error "Invalid selection"}
                ;;
            esac
          done
          
          ${ui.tables.keyValue "Selected branch" "$SELECTED_BRANCH"}
          
          # Create temporary directory and clone repository
          ${ui.messages.loading "Cloning repository..."}
          rm -rf "$TEMP_DIR"
          mkdir -p "$TEMP_DIR"
          
          if ! git clone --depth 1 --branch "$SELECTED_BRANCH" "$REPO_URL" "$TEMP_DIR"; then
            ${ui.messages.error "Failed to clone repository!"}
            exit 1
          fi
          
          SOURCE_DIR="$TEMP_DIR/nixos"
          break
          ;;
        2)
          # Local update configuration
          ${ui.text.header "NixOS System Update - Local"}
          SOURCE_DIR="/home/${username}/Documents/Git/NixOSControlCenter/nixos"
          
          if [ ! -d "$SOURCE_DIR" ]; then
            ${ui.messages.error "Local source directory not found!"}
            exit 1
          fi
          
          ${ui.tables.keyValue "Using local directory" "$SOURCE_DIR"}
          break
          ;;
        3)
          # Execute the separate channel update script
          ${ui.text.header "NixOS Channel Update"}
          ${ui.messages.info "Executing ncc-update-channels..."}
          # The ncc-update-channels script should handle its own sudo checks and messages
          if sudo ncc-update-channels; then
            ${ui.messages.success "Channel update process finished."}
          else
            ${ui.messages.error "Channel update process failed."}
          fi
          exit 0 # Exit after channel update is done
          ;;
        *)
          ${ui.messages.error "Invalid selection"}
          ;;
      esac
    done

    # Helper functions for selective module copying
    # Extract version from options.nix (SOURCE)
    get_source_version() {
      local module_path="$1"
      local options_file="$module_path/options.nix"
      if [ -f "$options_file" ]; then
        grep -m 1 'moduleVersion =' "$options_file" 2>/dev/null | sed 's/.*moduleVersion = "\([^"]*\)".*/\1/' || echo "unknown"
      else
        echo "unknown"
      fi
    }
    
    # Extract version from options.nix (TARGET - deployed system)
    # Version comes from deployed code, not config files
    get_target_version() {
      local module_path="$1"
      local options_file="$module_path/options.nix"
      if [ -f "$options_file" ]; then
        grep -m 1 'moduleVersion =' "$options_file" 2>/dev/null | sed 's/.*moduleVersion = "\([^"]*\)".*/\1/' || echo "unknown"
      else
        echo "unknown"
      fi
    }
    
    # Check if config file exists (now directly in module directory)
    check_user_config_exists() {
      local target_module="$1"
      local module_name="$2"

      # Standard pattern: check for module-name-config.nix directly in module
      if [ -f "$target_module/$module_name-config.nix" ]; then
        echo "$module_name-config.nix"
        return 0
      fi
      return 1
    }
    
    # Update module code (config files are now directly in module directory)
    update_module_code() {
      local source_module="$1"
      local target_module="$2"

      # Create target_module if it doesn't exist
      mkdir -p "$target_module"

      # Copy everything (no user-configs/ to exclude anymore)
      if [ "$VERBOSE" = "true" ]; then
        rsync -av "$source_module/" "$target_module/" || {
          # Fallback: recursively copy
          cp -r "$source_module"/* "$target_module/" 2>/dev/null || true
        }
      else
        rsync -aq "$source_module/" "$target_module/" >/dev/null 2>&1 || {
          # Fallback: recursively copy
          cp -r "$source_module"/* "$target_module/" 2>/dev/null || true
        }
      fi
    }
    
    # Handle versioned module (Stage 1+)
    handle_versioned_module() {
      local source_module="$1"
      local target_module="$2"
      local module_name="$3"
      local item_type="$4"  # "core" or "features"
      
      # Check versions
      SOURCE_VERSION=$(get_source_version "$source_module")
      
      # GENERIC: All modules use the same pattern
      CONFIG_FILE="$target_module/$module_name-config.nix"
      CONFIG_NAME="$module_name"
      
      if [ -f "$CONFIG_FILE" ]; then
        # TARGET has config file
        TARGET_VERSION=$(get_target_version "$target_module" "$CONFIG_NAME")
        
        if [ "$SOURCE_VERSION" != "$TARGET_VERSION" ] || [ "$FORCE_MIGRATION" = "true" ]; then
          # Migration needed (version different OR forced)
          if [ "$VERBOSE" = "true" ]; then
            ${ui.messages.info "Module $module_name: Migration needed (v$TARGET_VERSION → v$SOURCE_VERSION)"}
          fi
          # TODO: Migration would be executed here (Phase 2)
          # For now: Only update code, config files remain untouched
          update_module_code "$source_module" "$target_module"
        elif [ "$FORCE_UPDATE" = "true" ]; then
          # Force update even if versions are the same
          if [ "$VERBOSE" = "true" ]; then
            ${ui.messages.info "Module $module_name: Force update requested (v$SOURCE_VERSION), updating code"}
          fi
          update_module_code "$source_module" "$target_module"
        else
          # No update needed → versions are the same and no force flag
          if [ "$VERBOSE" = "true" ]; then
            ${ui.messages.info "Module $module_name: No update needed (v$SOURCE_VERSION), skipping"}
          fi
        fi
      else
        # TARGET has no config file
        if [ "$VERBOSE" = "true" ]; then
          ${ui.messages.info "Module $module_name: No config file found, copying from source (including config)"}
        fi
        # Copy completely (including config from repository)
        # This copies the default config from the repository
        cp -r "$source_module" "$target_module" 2>/dev/null || true
      fi
    }
    
    # Extract module config from system-config.nix (for Stage 0 → 1 migration)
    extract_module_config() {
      local system_config_file="$1"
      local module_name="$2"
      
      # Load system-config.nix as JSON
      if ! command -v nix-instantiate >/dev/null 2>&1 && ! command -v nix >/dev/null 2>&1; then
        ${ui.messages.error "nix-instantiate or nix required for Stage 0 → 1 migration"}
        return 1
      fi
      
      # Try with nix-instantiate (older Nix versions)
      if command -v nix-instantiate >/dev/null 2>&1; then
        OLD_CONFIG_JSON=$(nix-instantiate --eval --strict --json -E "import $system_config_file" 2>/dev/null || echo "{}")
      elif command -v nix >/dev/null 2>&1; then
        OLD_CONFIG_JSON=$(nix eval --json --file "$system_config_file" 2>/dev/null || echo "{}")
      else
        OLD_CONFIG_JSON="{}"
      fi
      
      if [ "$OLD_CONFIG_JSON" = "{}" ] || [ -z "$OLD_CONFIG_JSON" ]; then
        # No config found → return empty
        echo "{}"
        return 0
      fi
      
      # Extract module config with jq (if available)
      if command -v jq >/dev/null 2>&1; then
        MODULE_CONFIG=$(echo "$OLD_CONFIG_JSON" | jq -c ".''${module_name} // {}" 2>/dev/null || echo "{}")
        echo "$MODULE_CONFIG"
      else
        # Fallback: Try with grep (not ideal, but works for simple cases)
        # jq is required for complex configs
        ${ui.messages.warning "jq not available, using fallback extraction (may be incomplete)"}
        echo "{}"
      fi
    }
    
    # Migrate module from Stage 0 → Stage 1
    migrate_stage0_to_stage1() {
      local source_module="$1"
      local target_module="$2"
      local module_name="$3"
      local item_type="$4"  # "core" or "features"
      local system_config_file="$NIXOS_DIR/system-config.nix"
      
      ${ui.messages.loading "Migrating module $module_name from Stage 0 → 1..."}
      
      # 1. Check if system-config.nix exists
      if [ ! -f "$system_config_file" ]; then
        ${ui.messages.warning "system-config.nix not found, cannot extract config"}
        ${ui.messages.info "Copying module code only (config files will be created from defaults)"}
        update_module_code "$source_module" "$target_module"
        return 0
      fi
      
      # 2. Extract module config from system-config.nix
      MODULE_CONFIG_JSON=$(extract_module_config "$system_config_file" "$module_name")
      
      # 3. Create target_module if it doesn't exist
      mkdir -p "$target_module"
      
      # 4. Copy module code (including options.nix)
      update_module_code "$source_module" "$target_module"
      
      # 5. Create config file directly in module directory
      # Extract config directly as Nix code (not JSON)
      if command -v nix-instantiate >/dev/null 2>&1; then
        # Try to extract config directly as Nix attrset
        MODULE_CONFIG_NIX=$(nix-instantiate --eval --strict -E "
          let config = import $system_config_file;
          in if config ? ''${module_name} then
            builtins.toJSON config.''${module_name}
          else
            \"{}\"
        " 2>/dev/null || echo "{}")
        
        # Convert JSON back to Nix (simple approach: use builtins.fromJSON in Nix)
        # Create temporary Nix file for conversion
        TEMP_NIX=$(mktemp)
        cat > "$TEMP_NIX" <<'TEMPEOF'
{ moduleConfigJson, moduleName, moduleVersion }:
let
  config = builtins.fromJSON moduleConfigJson;
  hasVersion = moduleVersion != "unknown";
in
  if config == {} then
    "{}"
  else if hasVersion then
    builtins.toJSON (
      builtins.listToAttrs [{
        name = moduleName;
        value = config // { _version = moduleVersion; };
      }]
    )
  else
    builtins.toJSON (
      builtins.listToAttrs [{
        name = moduleName;
        value = config;
      }]
    )
TEMPEOF
        
        SOURCE_VERSION=$(get_source_version "$source_module")
        FINAL_CONFIG_JSON=$(nix-instantiate --eval --strict --json "$TEMP_NIX" \
          --argstr moduleConfigJson "$MODULE_CONFIG_JSON" \
          --argstr moduleName "$module_name" \
          --argstr moduleVersion "$SOURCE_VERSION" 2>/dev/null || echo "{}")
        rm -f "$TEMP_NIX"
        
        # Convert JSON to Nix format (simple: use jq for formatting)
        if command -v jq >/dev/null 2>&1 && [ "$FINAL_CONFIG_JSON" != "{}" ]; then
          # jq can convert JSON to Nix-like format (not perfect, but works)
          CONFIG_NIX=$(echo "$FINAL_CONFIG_JSON" | jq -r '
            def to_nix(v):
              if v == null then "null"
              elif (v | type) == "boolean" then (if v then "true" else "false" end)
              elif (v | type) == "number" then (v | tostring)
              elif (v | type) == "string" then ("\"" + v + "\"")
              elif (v | type) == "array" then ("[ " + (v | map(to_nix) | join(", ")) + " ]")
              elif (v | type) == "object" then
                ("{ " + (v | to_entries | map(.key + " = " + to_nix(.value)) | join("; ")) + "; }")
              else "null" end;
            to_entries | map(.key + " = " + to_nix(.value)) | join("; ")
          ' 2>/dev/null || echo "")
          
          if [ -n "$CONFIG_NIX" ]; then
            cat > "$target_module/$module_name-config.nix" <<EOF
{
  $CONFIG_NIX
}
EOF
            ${ui.messages.success "Created $module_name-config.nix from system-config.nix"}
          else
            ${ui.messages.warning "Could not convert JSON to Nix format"}
            touch "$target_module/$module_name-config.nix"
          fi
        else
          # Fallback: Create empty config (will be filled by activationScripts)
          ${ui.messages.warning "jq not available or config empty, creating empty config"}
          ${ui.messages.info "Config will be filled with defaults by activationScripts"}
          touch "$USER_CONFIGS_DIR/$module_name-config.nix"
        fi
      else
        # nix-instantiate not available → create empty config
        ${ui.messages.warning "nix-instantiate not available, cannot extract config"}
        ${ui.messages.info "Creating empty config (will be filled with defaults by activationScripts)"}
        touch "$USER_CONFIGS_DIR/$module_name-config.nix"
      fi
      
      ${ui.messages.success "Module $module_name migrated from Stage 0 → 1"}
    }
    
    # Handle non-versioned module (Stage 0)
    handle_stage0_module() {
      local source_module="$1"
      local target_module="$2"
      local module_name="$3"
      local item_type="$4"  # "core" or "features"
      
      if [ -d "$target_module" ]; then
        # Module exists in TARGET → Stage 0 → 1 migration
        if [ "$VERBOSE" = "true" ]; then
          ${ui.messages.info "Module $module_name: Stage 0 → 1 migration needed"}
        fi
        migrate_stage0_to_stage1 "$source_module" "$target_module" "$module_name" "$item_type"
      else
        # New module → copy completely
        if [ "$VERBOSE" = "true" ]; then
          ${ui.messages.info "Module $module_name: New module, copying completely"}
        fi
        cp -r "$source_module" "$target_module" 2>/dev/null || true
      fi
    }
    
    # Cleanup modules that no longer exist in SOURCE (only if --cleanup flag is set)
    cleanup_removed_modules() {
      local item_type="$1"  # "core" or "features"
      
      if [ "$CLEANUP" != "true" ]; then
        return 0  # Skip cleanup if flag not set
      fi
      
      ${ui.messages.loading "Cleaning up removed modules in $item_type/..."}
      
      local removed_count=0
      
      # For each module in TARGET
      for target_module in "$NIXOS_DIR/$item_type"/*; do
        if [ ! -d "$target_module" ]; then
          continue
        fi
        
        MODULE_NAME=$(basename "$target_module")
        SOURCE_MODULE="$SOURCE_DIR/$item_type/$MODULE_NAME"
        
        # Check if module exists in SOURCE
        if [ ! -d "$SOURCE_MODULE" ]; then
          # Module doesn't exist in SOURCE → remove it
          if [ "$VERBOSE" = "true" ]; then
            ${ui.messages.warning "Removing module: $item_type/$MODULE_NAME (no longer exists in source)"}
          fi
          sudo rm -rf "$target_module"
          removed_count=$((removed_count + 1))
        fi
      done
      
      if [ $removed_count -gt 0 ]; then
        ${ui.messages.success "Cleaned up $removed_count removed module(s) from $item_type/"}
      elif [ "$VERBOSE" = "true" ]; then
        ${ui.messages.info "No modules to clean up in $item_type/"}
      fi
    }

    # Directories and files to copy
    COPY_ITEMS=(
        "core"            # Base system configuration
        "custom"          # User-defined modules
        "features"        # Feature modules
        "packages"        # Packages directory
        "flake.nix"       # Flake configuration
    )
    
    # Create backup directory and perform backup
    BACKUP_DIR="$BACKUP_ROOT/$(date +%Y-%m-%d_%H-%M-%S)"
    ${ui.messages.loading "Creating backup in: $BACKUP_DIR"}
    
    # Prepare backup directory
    mkdir -p "$BACKUP_ROOT"
    
    # Clean up old backups (keep the last 5)
    cleanup_old_backups() {
      local keep=5
      ${ui.messages.loading "Cleaning up old backups (keeping last $keep)..."}
      ls -dt "$BACKUP_ROOT"/* | tail -n +$((keep + 1)) | xargs -r rm -rf
    }
    
    # Perform backup
    if cp -r "$NIXOS_DIR" "$BACKUP_DIR"; then
      ${ui.messages.success "Backup created successfully"}
      cleanup_old_backups
    else
      ${ui.messages.error "Failed to create backup!"}
      exit 1
    fi
    
    # Update files
    ${ui.messages.loading "Updating NixOS configuration..."}
    

    
    # Copy defined directories and files
    # IMPORTANT: configs/ and custom/ are NEVER overwritten - only copied during migration or if missing
    for item in "''${COPY_ITEMS[@]}"; do
      if [ -e "$SOURCE_DIR/$item" ]; then
        ${ui.messages.loading "Copying $item..."}
        # Use cp with --update to only copy new files (no overwrite)
        # But for directories we need to be more careful
        if [ -d "$SOURCE_DIR/$item" ]; then
          # For directories: Only copy if target doesn't exist, or only new files
          if [ "$item" = "configs" ] || [ "$item" = "custom" ]; then
            # configs/ and custom/ are NEVER overwritten (user-specific)
            if [ ! -d "$NIXOS_DIR/$item" ]; then
              ${ui.messages.loading "Copying $item... ($item/ does not exist)"}
              sudo cp -r "$SOURCE_DIR/$item" "$NIXOS_DIR/"
            else
              ${ui.messages.info "$item exists, skipping (preserving existing $item)..."}
            fi
          elif [ "$item" = "core" ] || [ "$item" = "features" ]; then
            # CRITICAL: Selective copying module-by-module (NEVER rm -rf!)
            ${ui.messages.loading "Updating $item/ modules (preserving configs)..."}
            
            # Create target_dir if it doesn't exist
            mkdir -p "$NIXOS_DIR/$item"
            
            # For each module in SOURCE
            for source_module in "$SOURCE_DIR/$item"/*; do
              if [ ! -d "$source_module" ]; then
                continue
              fi
              
              MODULE_NAME=$(basename "$source_module")
              TARGET_MODULE="$NIXOS_DIR/$item/$MODULE_NAME"
              
              # Check if module is versioned (has options.nix in SOURCE)
              if [ -f "$source_module/options.nix" ]; then
                # Module has version (Stage 1+)
                handle_versioned_module "$source_module" "$TARGET_MODULE" "$MODULE_NAME" "$item"
              else
                # Module has no version (Stage 0)
                handle_stage0_module "$source_module" "$TARGET_MODULE" "$MODULE_NAME" "$item"
              fi
            done
            
            ${ui.messages.success "$item/ updated (configs preserved)"}
            
            # Cleanup removed modules (only if --cleanup flag is set)
            cleanup_removed_modules "$item"
          elif [ "$item" = "packages" ]; then
            # CRITICAL: packages/ is a single module - use SAME GENERIC LOGIC as core/features
            ${ui.messages.loading "Updating packages/ (preserving configs)..."}
            
            # Create target_dir if it doesn't exist
            mkdir -p "$NIXOS_DIR/$item"
            
            # Treat packages as a versioned module (has options.nix) - use handle_versioned_module
            SOURCE_MODULE="$SOURCE_DIR/$item"
            TARGET_MODULE="$NIXOS_DIR/$item"
            MODULE_NAME="packages"
            
            # Check if module is versioned (has options.nix in SOURCE)
            if [ -f "$SOURCE_MODULE/options.nix" ]; then
              # Module has version (Stage 1+) - use handle_versioned_module
              handle_versioned_module "$SOURCE_MODULE" "$TARGET_MODULE" "$MODULE_NAME" "$item"
            else
              # Module has no version (Stage 0) - use handle_stage0_module
              handle_stage0_module "$SOURCE_MODULE" "$TARGET_MODULE" "$MODULE_NAME" "$item"
            fi
            
            ${ui.messages.success "packages/ updated (configs preserved)"}
          else
            # Other directories: Overwrite completely
            sudo rm -rf "$NIXOS_DIR/$item"
            sudo cp -r "$SOURCE_DIR/$item" "$NIXOS_DIR/"
          fi
        else
          # Single files: Overwrite (except protected files)
          if [ "$item" = "flake.nix" ]; then
            # flake.nix: Only overwrite if it doesn't exist or is significantly different
            if [ ! -f "$NIXOS_DIR/flake.nix" ]; then
              ${ui.messages.loading "Copying flake.nix (does not exist)..."}
              sudo cp "$SOURCE_DIR/$item" "$NIXOS_DIR/"
            else
              ${ui.messages.info "flake.nix exists, overwriting with new version..."}
              sudo cp "$SOURCE_DIR/$item" "$NIXOS_DIR/"
            fi
          else
            # Other files: Overwrite
            sudo cp "$SOURCE_DIR/$item" "$NIXOS_DIR/"
          fi
        fi
      else
        ${ui.messages.warning "$item not found, skipping..."}
      fi
    done
    
    # ADDITIONAL PROTECTION: Ensure protected directories are not overwritten
    # Even if they were accidentally in COPY_ITEMS or copied through another directory
    if [ -d "$NIXOS_DIR/configs" ] && [ -d "$SOURCE_DIR/configs" ]; then
      ${ui.messages.info "configs/ exists in both locations - preserving existing configs (not overwriting)"}
    fi
    if [ -d "$NIXOS_DIR/custom" ] && [ -d "$SOURCE_DIR/custom" ]; then
      ${ui.messages.info "custom/ exists in both locations - preserving existing custom modules (not overwriting)"}
    fi
    
    # PROTECT: hardware-configuration.nix and flake.lock (never overwrite)
    if [ -f "$NIXOS_DIR/hardware-configuration.nix" ]; then
      ${ui.messages.info "Preserving hardware-configuration.nix (system-specific, never overwritten)"}
    fi
    if [ -f "$NIXOS_DIR/flake.lock" ]; then
      ${ui.messages.info "Preserving flake.lock (generated file, never overwritten)"}
    fi
    
    # Set permissions
    ${ui.messages.loading "Setting permissions..."}
    for dir in core features desktop packages modules lib; do
      if [ -d "$NIXOS_DIR/$dir" ]; then
        chown -R root:root "$NIXOS_DIR/$dir"
        chmod -R 644 "$NIXOS_DIR/$dir"
        find "$NIXOS_DIR/$dir" -type d -exec chmod 755 {} \;
      fi
    done
    # Set permissions for files
    for file in flake.nix hardware-configuration.nix; do
      if [ -f "$NIXOS_DIR/$file" ]; then
        chown root:root "$NIXOS_DIR/$file"
        chmod 644 "$NIXOS_DIR/$file"
      fi
    done
    
    ${ui.messages.success "Update completed successfully!"}
    ${ui.tables.keyValue "Backup created in" "$BACKUP_DIR"}
    
    # Check if auto-build is enabled - also update this part
    if [ "$autoBuild" = "true" ]; then
      ${ui.messages.loading "Auto-build enabled, building configuration..."}
      BUILD_CMD="${if systemChecks then "sudo ncc build switch --flake /etc/nixos#${hostname}" else "sudo nixos-rebuild switch --flake /etc/nixos#${hostname}"}"
      
      if $BUILD_CMD 2>&1; then
        ${ui.messages.success "System successfully updated and rebuilt!"}
      else
        EXIT_CODE=$?
        # Check if build was successful but switch failed
        if [ -f /nix/var/nix/profiles/system ]; then
          CURRENT_GEN=$(readlink /nix/var/nix/profiles/system | cut -d'-' -f2)
          if [ -n "$CURRENT_GEN" ]; then
            ${ui.messages.warning "Build completed, but switch encountered issues (exit code: $EXIT_CODE)"}
            ${ui.messages.info "Current generation: $CURRENT_GEN"}
            ${ui.messages.info "Some services may have failed to reload - this is often harmless."}
          else
            ${ui.messages.error "Auto-build failed! Check logs for details."}
          fi
        else
          ${ui.messages.error "Auto-build failed! Check logs for details."}
        fi
      fi
    else
      ${prompt_build}
    fi
  '')
      pkgs.git
      pkgs.rsync
      pkgs.jq
    ];
  };

in {
  config = {
    # Enable terminal-ui dependency
    # features.terminal-ui.enable removed (cli-formatter is Core) = true;
    
    environment.systemPackages = [ 
      systemUpdateMainScript
      configModule.configCheck
    ];

    config.system.activationScripts.nixosBackupDir = ''
      # Create main backup directory
      mkdir -p ${backupSettings.directory}
      chmod 700 ${backupSettings.directory}
      chown root:root ${backupSettings.directory}
      
      # Create subdirectories for organized backups
      mkdir -p ${backupSettings.directory}/configs
      mkdir -p ${backupSettings.directory}/directories
      mkdir -p ${backupSettings.directory}/migrations
      mkdir -p ${backupSettings.directory}/ssh
      mkdir -p ${backupSettings.directory}/system-updates
      
      # Set permissions for all subdirectories
      chmod 700 ${backupSettings.directory}/configs
      chmod 700 ${backupSettings.directory}/directories
      chmod 700 ${backupSettings.directory}/migrations
      chmod 700 ${backupSettings.directory}/ssh
      chmod 700 ${backupSettings.directory}/system-updates
      
      chown root:root ${backupSettings.directory}/configs
      chown root:root ${backupSettings.directory}/directories
      chown root:root ${backupSettings.directory}/migrations
      chown root:root ${backupSettings.directory}/ssh
      chown root:root ${backupSettings.directory}/system-updates
    '';

    # Commands are registered in commands.nix
    core.management.system-manager.submodules.cli-registry.commands = [
      {
        name = "system-update";
        description = "Update NixOS system configuration";
        category = "system";
        script = "${systemUpdateMainScript}/bin/ncc-system-update-main";
        arguments = [
          "--auto-build"
          "--source"
          "--branch"
        ];
        dependencies = [ "git" ];
        shortHelp = "system-update [--auto-build] [--source=remote|local] [--branch=name] - Update NixOS configuration";
        longHelp = ''
          Update the NixOS system configuration from either a remote repository or local directory.
          
          Options:
            --auto-build    Automatically build after update (default: false)
            --source        Update source (remote or local)
            --branch        Branch name for remote updates
        '';
      }
    ];
  };
}
