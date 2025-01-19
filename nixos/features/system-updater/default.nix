{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  ui = config.features.terminal-ui.api;
  commandCenter = config.features.command-center;

  # Extract configuration values
  username = head (attrNames systemConfig.users);
  hostname = systemConfig.hostName;
  autoBuild = systemConfig.features.system-updater.auto-build or false;
  # Function to prompt for build
  prompt_build = ''
    while true; do
      printf "Do you want to build and switch to the new configuration? (y/n): "
      read build_choice
      case $build_choice in
        y|Y)
          ${ui.messages.loading "Building system configuration..."}
          if sudo ncc build switch --flake /etc/nixos#${hostname}; then
            ${ui.messages.success "System successfully updated and rebuilt!"}
          else
            ${ui.messages.error "Build failed! Check logs for details."}
          fi
          break
          ;;
        n|N)
          ${ui.messages.info "Skipping build. You can manually run: sudo ncc-build switch --flake /etc/nixos#${hostname}"}
          break
          ;;
        *)
          ${ui.messages.error "Invalid choice, please enter y or n"}
          ;;
      esac
    done
  '';
  
  updateScript = pkgs.writeScriptBin "ncc-updater" ''
    #!${pkgs.bash}/bin/bash
    set -e

    # Sudo-Check
    if [ "$EUID" -ne 0 ]; then
      ${ui.messages.error "This script must be run as root (use sudo)"}
      ${ui.messages.info "Usage: sudo $0"}
      exit 1
    fi

    # Konfiguration
    NIXOS_DIR="/etc/nixos"
    BACKUP_ROOT="/var/backup/nixos"
    
    ${ui.text.header "NixOS System Update"}
    ${ui.messages.info "Select update source:"}
    
    echo "1) Remote repository"
    echo "2) Local directory"
    
    while true; do
      printf "Select source (1-2): "
      read source_choice
      case $source_choice in
        1)
          # Remote update configuration
          REPO_URL="https://github.com/fr4iser90/NixOsControlCenter.git"
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
          
          # Temporäres Verzeichnis erstellen und Repository klonen
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
          SOURCE_DIR="/home/${username}/Documents/Git/NixOsControlCenter/nixos"
          
          if [ ! -d "$SOURCE_DIR" ]; then
            ${ui.messages.error "Local source directory not found!"}
            exit 1
          fi
          
          ${ui.tables.keyValue "Using local directory" "$SOURCE_DIR"}
          break
          ;;
        *)
          ${ui.messages.error "Invalid selection"}
          ;;
      esac
    done

    # Zu kopierende Verzeichnisse und Dateien
    COPY_ITEMS=(
        "core"            # Basis-Systemkonfiguration
        "custom"          # Benutzerdefinierte Module
        "desktop"         # Desktop-Umgebungen
        "features"        # Feature-Module
        "packages"        # Pakete-Verzeichnis
        "flake.nix"      # Flake-Konfiguration
        "modules"         # Legacy-Module (falls noch benötigt)
        "overlays"        # Overlays falls vorhanden
        "hosts"           # Host-spezifische Konfigurationen
        "lib"             # Bibliotheken
        "config"          # Zusätzliche Konfigurationen
    )
    
    # Backup-Verzeichnis erstellen und Backup machen
    BACKUP_DIR="$BACKUP_ROOT/$(date +%Y-%m-%d_%H-%M-%S)"
    ${ui.messages.loading "Creating backup in: $BACKUP_DIR"}
    
    # Backup-Verzeichnis vorbereiten
    mkdir -p "$BACKUP_ROOT"
    
    # Alte Backups aufräumen (behalte die letzten 5)
    cleanup_old_backups() {
      local keep=5
      ${ui.messages.loading "Cleaning up old backups (keeping last $keep)..."}
      ls -dt "$BACKUP_ROOT"/* | tail -n +$((keep + 1)) | xargs -r rm -rf
    }
    
    # Backup durchführen
    if cp -r "$NIXOS_DIR" "$BACKUP_DIR"; then
      ${ui.messages.success "Backup created successfully"}
      cleanup_old_backups
    else
      ${ui.messages.error "Failed to create backup!"}
      exit 1
    fi
    
    # Dateien aktualisieren
    ${ui.messages.loading "Updating NixOS configuration..."}
    
    # Entferne alte Verzeichnisse
    sudo rm -rf "$NIXOS_DIR/modules" "$NIXOS_DIR/lib" "$NIXOS_DIR/packages" "$NIXOS_DIR/flake.nix"
    
    # Kopiere definierte Verzeichnisse und Dateien
    for item in "''${COPY_ITEMS[@]}"; do
      if [ -e "$SOURCE_DIR/$item" ]; then
        ${ui.messages.loading "Copying $item..."}
        sudo cp -r "$SOURCE_DIR/$item" "$NIXOS_DIR/"
      else
        ${ui.messages.warning "$item not found, skipping..."}
      fi
    done
    
    # Berechtigungen setzen
    ${ui.messages.loading "Setting permissions..."}
    for dir in modules lib packages; do
      if [ -d "$NIXOS_DIR/$dir" ]; then
        chown -R root:root "$NIXOS_DIR/$dir"
        chmod -R 644 "$NIXOS_DIR/$dir"
        find "$NIXOS_DIR/$dir" -type d -exec chmod 755 {} \;
      fi
    done
    chown root:root "$NIXOS_DIR/flake.nix"
    chmod 644 "$NIXOS_DIR/flake.nix"
    
    ${ui.messages.success "Update completed successfully!"}
    ${ui.tables.keyValue "Backup created in" "$BACKUP_DIR"}
    
    # Check if auto-build is enabled
    if autoBuild; then
      ${ui.messages.loading "Auto-build enabled, building configuration..."}
      if sudo ncc build switch --flake /etc/nixos#${hostname}; then
        ${ui.messages.success "System successfully updated and rebuilt!"}
      else
        ${ui.messages.error "Auto-build failed! Check logs for details."}
      fi
    else
      ${prompt_build}
    fi
  '';

in {
  config = {
    environment.systemPackages = [ 
      updateScript
      pkgs.git 
    ];

    system.activationScripts.nixosBackupDir = ''
      mkdir -p /var/backup/nixos
      chmod 700 /var/backup/nixos
      chown root:root /var/backup/nixos
    '';

    features.command-center.commands = [
      {
        name = "system-update";
        description = "Update NixOS system configuration";
        category = "system";
        script = "${updateScript}/bin/ncc-updater";
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
        autoBuild = false;
        updateSources = [
          {
            name = "remote";
            url = "https://github.com/fr4iser90/NixOsControlCenter.git";
            branches = [ "main" "develop" "experimental" ];
          }
          {
            name = "local";
            url = "/home/${username}/Documents/Git/NixOsControlCenter/nixos";
            branches = [];
          }
        ];
        backupSettings = {
          enabled = true;
          retention = 5;
          directory = "/var/backup/nixos";
        };
      }
    ];
  };
}
