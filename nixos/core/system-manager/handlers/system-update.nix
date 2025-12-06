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

  ui = config.core.cli-formatter.api;
  commandCenter = config.core.command-center;

  # Extract configuration values
  username = head (attrNames systemConfig.users);
  hostname = systemConfig.hostName;
  autoBuild = config.core.system-manager.auto-build or false;
  systemChecks = systemConfig.features.system-checks or false;
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
  # Terminal-UI is imported directly in core/config, no need to pass it
  configModule = import ../../config { inherit pkgs lib; };
  
  systemUpdateMainScript = pkgs.writeScriptBin "ncc-system-update-main" ''
    #!${pkgs.bash}/bin/bash
    set -e

    # Parse arguments for verbose mode
    VERBOSE=false
    for arg in "$@"; do
      case "$arg" in
        --verbose|--debug|-v)
          VERBOSE=true
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

    # Directories and files to copy
    COPY_ITEMS=(
        "core"            # Base system configuration
        "custom"          # User-defined modules
        "desktop"         # Desktop environments
        "features"        # Feature modules
        "packages"        # Packages directory
        "flake.nix"       # Flake configuration
        "modules"         # Legacy modules (if still needed)
        "overlays"        # Overlays if present
        "hosts"           # Host-specific configurations
        "lib"             # Libraries
        "config"          # Additional configurations
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
    
    # Remove old directories (legacy, not in COPY_ITEMS)
    sudo rm -rf "$NIXOS_DIR/modules" "$NIXOS_DIR/lib" "$NIXOS_DIR/packages"
    # Note: flake.nix is handled separately below
    
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
            # For core/ and features/: Replace completely, but clean up old subdirectories first
            ${ui.messages.loading "Replacing $item/ completely..."}
            # Remove old directory completely
            sudo rm -rf "$NIXOS_DIR/$item"
            # Copy new directory
            sudo cp -r "$SOURCE_DIR/$item" "$NIXOS_DIR/"
            ${ui.messages.success "$item/ replaced (old subdirectories removed)"}
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
  '';

in {
  config = {
    # Enable terminal-ui dependency
    # features.terminal-ui.enable removed (cli-formatter is Core) = true;
    
    environment.systemPackages = [ 
      systemUpdateMainScript
      configModule.configCheck
      pkgs.git 
    ];

    system.activationScripts.nixosBackupDir = ''
      mkdir -p ${backupSettings.directory}
      chmod 700 ${backupSettings.directory}
      chown root:root ${backupSettings.directory}
    '';

    # Commands are registered in commands.nix
    core.command-center.commands = [
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
