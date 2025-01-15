{ config, lib, pkgs, ... }:

with lib;

let
  ui = config.features.terminal-ui.api;
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
    REPO_URL="https://github.com/fr4iser90/NixOsControlCenter.git"
    NIXOS_DIR="/etc/nixos"
    TEMP_DIR="/tmp/nixos-update"
    BACKUP_ROOT="/var/backup/nixos"
    
    # Branch-Auswahl
    ${ui.text.header "NixOS System Update"}
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
    rm -rf "$NIXOS_DIR/modules" "$NIXOS_DIR/lib" "$NIXOS_DIR/packages" "$NIXOS_DIR/flake.nix"
    
    # Kopiere neue Verzeichnisse
    for dir in modules lib packages; do
      if [ -d "$TEMP_DIR/nixos/$dir" ]; then
        ${ui.messages.loading "Copying $dir..."}
        cp -r "$TEMP_DIR/nixos/$dir" "$NIXOS_DIR/"
      fi
    done
    
    # Kopiere flake.nix
    cp "$TEMP_DIR/nixos/flake.nix" "$NIXOS_DIR/"
    
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
    ${ui.messages.info "You can now run 'sudo ncc-build switch --flake /etc/nixos#HostName' to apply changes."}
  '';

in {
  config = {
    environment.systemPackages = [ 
      updateScript
      pkgs.git 
    ];

    environment.shellAliases = {
      "ncc-system-update" = "ncc-updater";
      "ncc-update" = "ncc-updater";
      "nixos-flake-update" = "ncc-updater";
    };

    system.activationScripts.nixosBackupDir = ''
      mkdir -p /var/backup/nixos
      chmod 700 /var/backup/nixos
      chown root:root /var/backup/nixos
    '';
  };
}