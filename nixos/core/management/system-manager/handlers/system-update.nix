{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, cliRegistry, ... }:

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

  ui = getModuleApi "cli-formatter";
  commandCenter = getModuleConfig "cli-registry";

  # Extract configuration values
  userCfg = getModuleConfig "user";
  username = if attrNames userCfg == [] then "root" else head (attrNames userCfg);
  hostname = lib.attrByPath ["hostName"] "nixos" (getModuleConfig "network");
  autoBuild = lib.attrByPath ["autoBuild"] false (getModuleConfig "system-manager");
  systemChecks = lib.attrByPath ["enable"] false (getModuleConfig "system-checks");
  # Function to prompt for build - with conditional build command and better error handling
  prompt_build = ''
    while true; do
      printf "Do you want to build and switch to the new configuration? (y/n): "
      read build_choice
      case $build_choice in
        y|Y)
          ${ui.messages.loading "Building system configuration..."}
          BUILD_CMD="sudo ncc system build switch --flake /etc/nixos#${hostname}"
          
          # Run build and capture exit code (sh -c completely isolates from parent shell)
          if sh -c "$BUILD_CMD" 2>&1; then
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
          ${ui.messages.info "Skipping build. You can manually run: sudo ncc system build switch --flake /etc/nixos#${hostname}"}
          break
          ;;
        *)
          ${ui.messages.error "Invalid choice, please enter y or n"}
          ;;
      esac
    done
  '';
  
  # Import config management (single import, clean API)
  # CLI Formatter wird von config-migration selbst geholt
  configModule = import ./../components/config-migration { inherit config pkgs lib systemConfig getModuleApi; backupHelpers = import ../lib/backup-helpers.nix { inherit pkgs lib; }; };
  
  # Create script with runtime dependencies (only available for this script, not system-wide)
  systemUpdateMainScript = pkgs.symlinkJoin {
    name = "ncc-system-update-main";
    paths = [
      (pkgs.writeScriptBin "ncc-system-update-main" ''
    #!${pkgs.bash}/bin/bash
    set -e

    # Parse arguments for verbose mode, force-migration, force-update, cleanup, and auto-confirm
    VERBOSE=false
    FORCE_MIGRATION=false
    FORCE_UPDATE=false
    CLEANUP=false
    AUTO_CONFIRM=false
    AUTO_SOURCE=""
    AUTO_BUILD=false
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
        --yes|-y|--auto)
          AUTO_CONFIRM=true
          ;;
        --local)
          AUTO_SOURCE="local"
          ;;
        --remote)
          AUTO_SOURCE="remote"
          ;;
        --channels)
          AUTO_SOURCE="channels"
          ;;
        --auto-build)
          AUTO_BUILD=true
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
    
    # Show dangerous warning unless auto-confirm is enabled
    if [ "$AUTO_CONFIRM" != "true" ]; then
      ${ui.messages.warning "WARNING: This command is potentially dangerous!"}
      ${ui.messages.info "This may cause system instability or data loss."}
      while true; do
        printf "Do you want to continue? (yes/no): "
        read confirm_choice
        case $confirm_choice in
          yes|y|Y)
            ${ui.messages.info "Proceeding with dangerous command..."}
            echo ""
            break
            ;;
          no|n|N)
            ${ui.messages.info "Operation cancelled by user."}
            exit 0
            ;;
          *)
            ${ui.messages.error "Please answer yes or no"}
            ;;
        esac
      done
    fi
    
    ${ui.text.header "NixOS System Update"}
    
    # Step 1: Check system configuration (validates + migrates if needed)
    # ncc-config-check already outputs status messages, so we just check the exit code
    if ! ${configModule.configCheck}/bin/ncc-config-check $([ "$VERBOSE" = "true" ] && echo "--verbose") 2>&1; then
      ${ui.messages.warning "Configuration has issues (migration may have been attempted)"}
      if [ "$AUTO_CONFIRM" != "true" ]; then
        ${ui.messages.info "You may want to review the configuration before proceeding"}
      fi
    fi
    
    # Auto-select source if specified
    if [ -n "$AUTO_SOURCE" ]; then
      case "$AUTO_SOURCE" in
        local)
          source_choice=2
          ;;
        remote)
          source_choice=1
          ;;
        channels)
          source_choice=3
          ;;
        *)
          ${ui.messages.error "Invalid auto-source value: $AUTO_SOURCE"}
          exit 1
          ;;
      esac
    else
      ${ui.messages.info "Select update source or action:"}
      
      echo "1) Update Configuration (Remote Repository)"
      echo "2) Update Configuration (Local Directory)"
      echo "3) Update Channels (flake inputs)"
      
      printf "Select option (1-3): "
      read source_choice
    fi
    
    while true; do
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
            ${ui.messages.warning "Default directory not found: $SOURCE_DIR"}
            ${ui.messages.info "Looking for NixOS flakes in common locations..."}
            
            while true; do
              echo ""
              echo "1) Select from detected NixOS flakes (fzf)"
              echo "2) Browse directories (fzf)"
              echo "3) Enter path manually"
              echo "4) Cancel"
              printf "Select option (1-4): "
              read local_choice
              
              case $local_choice in
                1)
                  # Auto-detect directories containing flake.nix
                  FLAKE_DIRS=$(find /home /opt /srv /mnt -maxdepth 6 -name "flake.nix" -type f 2>/dev/null | xargs -I{} dirname {} 2>/dev/null | sort -u)
                  
                  if [ -z "$FLAKE_DIRS" ]; then
                    ${ui.messages.error "No NixOS flakes found automatically"}
                    ${ui.messages.info "Try option 2 to browse or 3 for manual entry"}
                  else
                    SELECTED=$(echo "$FLAKE_DIRS" | fzf --height=50% --border --prompt="Select NixOS source > ")
                    if [ -n "$SELECTED" ] && [ -d "$SELECTED" ]; then
                      SOURCE_DIR="$SELECTED"
                      break
                    fi
                  fi
                  ;;
                2)
                  # Browse with fzf + tree preview
                  BROWSE_DIR=$(find /home /opt /srv /mnt -maxdepth 6 -type d 2>/dev/null | \
                    fzf --height=70% --border \
                    --header="Navigate to your NixOS source directory" \
                    --preview='tree -C -L 1 {}' \
                    --prompt="Directory > ")
                  
                  if [ -n "$BROWSE_DIR" ] && [ -d "$BROWSE_DIR" ]; then
                    SOURCE_DIR="$BROWSE_DIR"
                    break
                  else
                    ${ui.messages.error "No directory selected"}
                  fi
                  ;;
                3)
                  printf "Enter path to NixOS source directory: "
                  read raw_path
                  SOURCE_DIR=$(eval echo "$raw_path")
                  if [ -d "$SOURCE_DIR" ]; then
                    break
                  else
                    ${ui.messages.error "Directory not found: $SOURCE_DIR"}
                  fi
                  ;;
                4)
                  ${ui.messages.info "Update cancelled"}
                  exit 0
                  ;;
                *)
                  ${ui.messages.error "Invalid selection"}
                  ;;
              esac
            done
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
    # Extract version from _module.metadata (SOURCE)
    get_source_version() {
      local module_path="$1"
      local default_file="$module_path/default.nix"
      if [ -f "$default_file" ]; then
        nix-instantiate --eval "$default_file" 2>/dev/null | jq -r '._module.metadata.version // "unknown"' 2>/dev/null || echo "unknown"
      else
        echo "unknown"
      fi
    }
    
    # Extract version from _module.metadata (TARGET - deployed system)
    # Version comes from deployed code, not config files
    get_target_version() {
      local module_path="$1"
      local default_file="$module_path/default.nix"
      if [ -f "$default_file" ]; then
        nix-instantiate --eval "$default_file" 2>/dev/null | jq -r '._module.metadata.version // "unknown"' 2>/dev/null || echo "unknown"
      else
        echo "unknown"
      fi
    }
    
    # Check if config file exists (now directly in module directory)
    check_user_config_exists() {
      local target_module="$1"
      local module_name="$2"

      # Standard pattern: check for config.nix in module subdirectory
      if [ -f "$target_module/$module_name/config.nix" ]; then
        echo "config.nix"
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
      local item_type="$4"  # "core" or "modules"
      
      # In v1-Architektur liegt die Modul-Konfiguration in systemConfig/,
      # NICHT im Modul-Verzeichnis (dort liegt nur die Modul-Definition config.nix)
      SYSTEM_CONFIG_FILE="$NIXOS_DIR/systemConfig/$item_type/$module_name/config.nix"
      
      if [ -f "$SYSTEM_CONFIG_FILE" ]; then
        # Config in systemConfig/ existiert → normaler Update-Prozess
        # Config bleibt erhalten, nur Modul-Code wird ggf. aktualisiert
        
        SOURCE_VERSION=$(get_source_version "$source_module")
        CONFIG_FILE="$target_module/$module_name/config.nix"
        
        if [ -f "$CONFIG_FILE" ]; then
          TARGET_VERSION=$(get_target_version "$target_module" "$module_name")
          
          if [ "$SOURCE_VERSION" != "$TARGET_VERSION" ] || [ "$FORCE_MIGRATION" = "true" ]; then
            if [ "$VERBOSE" = "true" ]; then
              ${ui.messages.info "Module $module_name: Migration needed (v$TARGET_VERSION → v$SOURCE_VERSION)"}
            fi
            update_module_code "$source_module" "$target_module"
          elif [ "$FORCE_UPDATE" = "true" ]; then
            if [ "$VERBOSE" = "true" ]; then
              ${ui.messages.info "Module $module_name: Force update requested (v$SOURCE_VERSION), updating code"}
            fi
            update_module_code "$source_module" "$target_module"
          else
            if [ "$VERBOSE" = "true" ]; then
              ${ui.messages.info "Module $module_name: No update needed (v$SOURCE_VERSION), skipping"}
            fi
          fi
        else
          # Modul-Verzeichnis hat kein config.nix → komplett aus Source kopieren
          if [ "$VERBOSE" = "true" ]; then
            ${ui.messages.info "Module $module_name: No module config file found, copying from source"}
          fi
          cp -r "$source_module" "$target_module" 2>/dev/null || true
        fi
      else
        # KEINE Config in systemConfig/ → Stage 0 → 1 Migration von system-config.nix
        # Dies passiert wenn der User noch im alten Format (v0) in system-config.nix definiert ist
        if [ "$VERBOSE" = "true" ]; then
          ${ui.messages.info "Module $module_name: No systemConfig found, running Stage 0 → 1 migration"}
        fi
        migrate_stage0_to_stage1 "$source_module" "$target_module" "$module_name" "$item_type"
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
      # NOTE: Manche Module haben Plural-Namen in der Config (z.B. "users" statt "user")
      # Daher versuchen wir sowohl Singular als auch Plural (module_name + "s")
      if command -v jq >/dev/null 2>&1; then
        MODULE_CONFIG=$(echo "$OLD_CONFIG_JSON" | jq -c ".''${module_name} // .''${module_name}s // {}" 2>/dev/null || echo "{}")
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
      local item_type="$4"  # "core" or "modules"

      local system_config_file="$NIXOS_DIR/system-config.nix"
      
      # v1 already active → just copy module code, skip migration noise
      if [ ! -f "$system_config_file" ]; then
        update_module_code "$source_module" "$target_module"
        return 0
      fi
      
      if [ "$VERBOSE" = "true" ]; then
        ${ui.messages.loading "Migrating module $module_name from Stage 0 → 1..."}
      fi
      
      # 2. Extract module config from system-config.nix
      MODULE_CONFIG_JSON=$(extract_module_config "$system_config_file" "$module_name")
      
      # 3. Create target_module if it doesn't exist
      mkdir -p "$target_module"
      
      # 4. Copy module code (including options.nix)
      update_module_code "$source_module" "$target_module"
      
      # 5. Create config file in systemConfig/ (v1-Architektur)
      # Configs liegen in systemConfig/$item_type/$module_name/config.nix,
      # NICHT im Modul-Verzeichnis (dort liegt nur der Modul-Code)
      SYSTEM_CONFIG_DIR="$NIXOS_DIR/systemConfig/$item_type/$module_name"
      mkdir -p "$SYSTEM_CONFIG_DIR"
      
      if command -v nix-instantiate >/dev/null 2>&1; then
        # Try to extract config directly as Nix attrset
        MODULE_CONFIG_NIX=$(nix-instantiate --eval --strict -E "
          let config = import $system_config_file;
              result = if config ? ''${module_name} then config.''${module_name}
                      else if config ? ''${module_name}s then config.''${module_name}s
                      else {};
          in builtins.toJSON result
        " 2>/dev/null || echo "{}")
        
        # Convert JSON back to Nix (simple approach: use builtins.fromJSON in Nix)
        # Create temporary Nix file for conversion
        TEMP_NIX=$(mktemp)
        cat > "$TEMP_NIX" <<'TEMPEOF'
{ moduleConfigJson, moduleName, moduleVersion }:
let
  config = builtins.fromJSON moduleConfigJson;
in
  if config == {} then
    "{}"
  else
    # Config wird FLAT geschrieben (ohne moduleName-Wrapper).
    # Der Config-Loader mapped via File-Path (systemConfig/.../config.nix → richtiger Scope).
    builtins.toJSON (config // (if moduleVersion != "unknown" then { _version = moduleVersion; } else {}))
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
            cat > "$SYSTEM_CONFIG_DIR/config.nix" <<EOF
{
  $CONFIG_NIX
}
EOF
            ${ui.messages.success "Created config.nix from system-config.nix"}
          else
            ${ui.messages.warning "Could not convert JSON to Nix format"}
            touch "$SYSTEM_CONFIG_DIR/config.nix"
          fi
        else
          # Fallback: Create empty config (will be filled by activationScripts)
          ${ui.messages.warning "jq not available or config empty, creating empty config"}
          ${ui.messages.info "Config will be filled with defaults by activationScripts"}
          touch "$SYSTEM_CONFIG_DIR/config.nix"
        fi
      else
        # nix-instantiate not available → create empty config
        ${ui.messages.warning "nix-instantiate not available, cannot extract config"}
        ${ui.messages.info "Creating empty config (will be filled with defaults by activationScripts)"}
        touch "$SYSTEM_CONFIG_DIR/config.nix"
      fi
      
      ${ui.messages.success "Module $module_name migrated from Stage 0 → 1"}
    }
    
    # Handle non-versioned module (Stage 0)
    handle_stage0_module() {
      local source_module="$1"
      local target_module="$2"
      local module_name="$3"
      local item_type="$4"  # "core" or "modules"
      
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
      local item_type="$1"  # "core" or "modules"
      
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
        "modules"        # Optional modules
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
          elif [ "$item" = "core" ] || [ "$item" = "modules" ]; then
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
            # CRITICAL: packages/ is a single module - use SAME GENERIC LOGIC as core/modules
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
     
      # Sync template-config.nix files to systemConfig/config.nix
      if [ "$VERBOSE" = "true" ]; then
        echo "=== Syncing config templates ==="
      fi
      SYNCED=0
      while IFS= read -r -d $'\0' tmpl_file; do
        rel_path="''${tmpl_file#$SOURCE_DIR/}"
        
        if [[ "$rel_path" == core/base/user/* ]]; then
          target_config="$NIXOS_DIR/systemConfig/$rel_path"
          target_config="''${target_config/template-config.nix/config.nix}"
          
          if [ -f "$target_config" ]; then
            continue
          fi
          
          if [ -f "$NIXOS_DIR/system-config.nix" ] && command -v nix-instantiate >/dev/null 2>&1; then
            if [ "$VERBOSE" = "true" ]; then
              echo "  [MIGRATING] $rel_path - extracting users from system-config.nix..."
            fi
            
            target_dir=$(dirname "$target_config")
            TMP_EXTRACT=$(mktemp)
            cat > "$TMP_EXTRACT" << 'NIXEOF'
{ configFile }:
let
  cfg = import configFile;
  data = if builtins.hasAttr "users" cfg then cfg.users
         else if builtins.hasAttr "user" cfg then cfg.user
         else {};
  toNix = v:
    if builtins.isBool v then if v then "true" else "false"
    else if builtins.isInt v then toString v
    else if builtins.isFloat v then toString v
    else if builtins.isString v then "\"" + v + "\""
    else if builtins.isList v then "[ " + builtins.concatStringsSep " " (map toNix v) + " ]"
    else if builtins.isAttrs v then
      "{ " + builtins.concatStringsSep "; " (builtins.mapAttrsToList (n: val: n + " = " + toNix val + ";") v) + " }"
    else "null";
in
  "{\n" + builtins.concatStringsSep ";\n" (builtins.mapAttrsToList (n: val: "  " + n + " = " + toNix val + ";") data) + "\n}\n"
NIXEOF
            
            USER_CONFIG_NIX=""
            if command -v nix >/dev/null 2>&1; then
              USER_CONFIG_NIX=$(nix eval --raw -f "$TMP_EXTRACT" --argstr configFile "$NIXOS_DIR/system-config.nix" 2>/dev/null || echo "")
            fi
            if [ -z "$USER_CONFIG_NIX" ]; then
              USER_CONFIG_RAW=$(nix-instantiate --eval --strict "$TMP_EXTRACT" --argstr configFile "$NIXOS_DIR/system-config.nix" 2>/dev/null || echo "")
              if [ -n "$USER_CONFIG_RAW" ]; then
                USER_CONFIG_RAW=''${USER_CONFIG_RAW#\"}
                USER_CONFIG_RAW=''${USER_CONFIG_RAW%\"}
                USER_CONFIG_RAW=''${USER_CONFIG_RAW//\\\"/\"}
                USER_CONFIG_RAW=''${USER_CONFIG_RAW//\\n/$'\n'}
                USER_CONFIG_RAW=''${USER_CONFIG_RAW//\\t/$'\t'}
                USER_CONFIG_NIX="$USER_CONFIG_RAW"
              fi
            fi
            rm -f "$TMP_EXTRACT"
            
            if [ -n "$USER_CONFIG_NIX" ] && [ "$USER_CONFIG_NIX" != "{}" ] && [ "$USER_CONFIG_NIX" != "{}\n" ]; then
              mkdir -p "$target_dir"
              printf '%s\n' "$USER_CONFIG_NIX" > "$target_config"
              SYNCED=$((SYNCED + 1))
              if [ "$VERBOSE" = "true" ]; then
                echo "  [CREATED] $(basename $target_config) in systemConfig/core/base/user/"
              fi
            fi
          fi
          continue
        fi
        
        target_config="$NIXOS_DIR/systemConfig/$rel_path"
        target_config="''${target_config/template-config.nix/config.nix}"
        target_dir=$(dirname "$target_config")
        if [ ! -f "$target_config" ]; then
          mkdir -p "$target_dir"
          cp "$tmpl_file" "$target_config"
          SYNCED=$((SYNCED + 1))
          if [ "$VERBOSE" = "true" ]; then
            echo "  [COPIED] $rel_path"
          fi
        fi
      done < <(find "$SOURCE_DIR/core" "$SOURCE_DIR/modules" -name "template-config.nix" -print0 2>/dev/null)
      if [ "$SYNCED" -gt 0 ]; then
        echo "  Synced $SYNCED config(s) from templates"
      elif [ "$VERBOSE" = "true" ]; then
        echo "  No template sync needed"
      fi
      
      # Fix placeholder hostname in synced configs
      ADJUSTED=0
      if [ -d "$NIXOS_DIR/systemConfig" ]; then
        for cf in $(find "$NIXOS_DIR/systemConfig" -name "config.nix" 2>/dev/null); do
          if grep -q 'hostName = "nixos"' "$cf" 2>/dev/null; then
            ch=$(hostname 2>/dev/null || echo "nixos")
            sed -i "s/hostName = \"nixos\"/hostName = \"$ch\"/g" "$cf"
            echo "  [FIXED] hostname → $ch in $(basename $(dirname $cf))"
            ADJUSTED=$((ADJUSTED + 1))
          fi
        done
      fi
      if [ "$ADJUSTED" -gt 0 ]; then
        echo "  Fixed $ADJUSTED placeholder(s)"
      fi
     
     # ADDITIONAL PROTECTION: Ensure protected directories are not overwritten
     # Even if they were accidentally in COPY_ITEMS or copied through another directory
     if [ -d "$NIXOS_DIR/systemConfig" ] && [ -d "$SOURCE_DIR/systemConfig" ]; then
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
    for dir in core modules desktop packages modules lib; do
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
    
    # PASSWORT-INTEGRITAET: Pruefe ob konfigurierte User Passwort-Dateien haben
    # Secrets werden nie vom Update ueberschrieben (nicht in COPY_ITEMS),
    # aber koennen durch Config-Fehler in vorherigen Builds verloren gegangen sein.
    ${ui.messages.loading "Checking password file integrity..."}
    PASSWORD_DIR="$NIXOS_DIR/secrets/passwords"
    pw_issues=0
    if [ -d "$PASSWORD_DIR" ]; then
      for user_dir in "$PASSWORD_DIR"/*; do
        [ -e "$user_dir" ] || continue
        user_name=$(basename "$user_dir")
        if [ ! -f "$user_dir/.hashedPassword" ]; then
          ${ui.badges.warning "User '$user_name' has password directory but no .hashedPassword file!"}
          pw_issues=$((pw_issues + 1))
        elif [ ! -s "$user_dir/.hashedPassword" ]; then
          ${ui.badges.warning "User '$user_name' has empty .hashedPassword file!"}
          pw_issues=$((pw_issues + 1))
        fi
      done
    fi
    if [ "$pw_issues" -gt 0 ]; then
      ${ui.badges.warning "$pw_issues user(s) have password issues - they will be prompted during prebuild checks"}
    else
      ${ui.badges.success "Password files OK"}
    fi
    
    # Check if auto-build or --auto-build flag is enabled
    if [ "$AUTO_BUILD" = "true" ] || [ "$autoBuild" = "true" ]; then
      ${ui.messages.loading "Auto-build enabled, building configuration..."}
      BUILD_CMD="sudo ncc system build switch --flake /etc/nixos#${hostname}"
      
      if sh -c "$BUILD_CMD" 2>&1; then
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
    elif [ "$AUTO_CONFIRM" = "true" ]; then
      # Auto-confirm enabled but no auto-build - skip build prompt
      ${ui.messages.info "Skipping build. You can manually run: sudo ncc system build switch --flake /etc/nixos#${hostname}"}
    else
      ${prompt_build}
    fi
  '')
      pkgs.git
      pkgs.rsync
      pkgs.jq
      pkgs.fzf
      pkgs.tree
    ];
  };

in lib.mkMerge [
  {
    # Enable terminal-ui dependency
    # modules.terminal-ui.enable removed (cli-formatter is Core) = true;

    environment.systemPackages = [
      systemUpdateMainScript
      configModule.configCheck
    ];

    system.activationScripts.nixosBackupDir = ''
      # Create main backup directory
      mkdir -p ${backupSettings.directory}
      chmod 700 ${backupSettings.directory}
      chown root:root ${backupSettings.directory}

      # Create subdirectories for organized backups
      mkdir -p ${backupSettings.directory}/systemConfig
      mkdir -p ${backupSettings.directory}/directories
      mkdir -p ${backupSettings.directory}/migrations
      mkdir -p ${backupSettings.directory}/ssh
      mkdir -p ${backupSettings.directory}/system-updates

      # Set permissions for all subdirectories
      chmod 700 ${backupSettings.directory}/systemConfig
      chmod 700 ${backupSettings.directory}/directories
      chmod 700 ${backupSettings.directory}/migrations
      chmod 700 ${backupSettings.directory}/ssh
      chmod 700 ${backupSettings.directory}/system-updates

      chown root:root ${backupSettings.directory}/systemConfig
      chown root:root ${backupSettings.directory}/directories
      chown root:root ${backupSettings.directory}/migrations
      chown root:root ${backupSettings.directory}/ssh
      chown root:root ${backupSettings.directory}/system-updates
    '';
  }

]
// 
{
  inherit systemUpdateMainScript;
}
