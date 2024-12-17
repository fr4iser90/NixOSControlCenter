{ config, lib, pkgs, ... }:

let
  update-flake = pkgs.writeScriptBin "update-nixos-flake" ''
    #!${pkgs.bash}/bin/bash
    
    # Sudo-Check
    if [ "$EUID" -ne 0 ]; then
      echo -e "''${RED}This script must be run as root (use sudo)''${NC}"
      echo "Usage: sudo update-nixos-flake"
      exit 1
    fi

    # Konfiguration
    REPO_URL="https://github.com/fr4iser90/NixOsControlCenter.git"
    NIXOS_DIR="/etc/nixos"
    TEMP_DIR="/tmp/nixos-update"
    BACKUP_ROOT="/var/backup/nixos"
    
    # Farben
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    NC='\033[0m'
    
    # Branch-Auswahl
    PS3="Select a branch: "
    branches=("main" "develop" "experimental" "custom")
    
    echo -e "''${YELLOW}Available branches:''${NC}"
    select branch in "''${branches[@]}"; do
      case $branch in
        "main"|"develop"|"experimental")
          SELECTED_BRANCH=$branch
          break
          ;;
        "custom")
          read -p "Enter custom branch name: " SELECTED_BRANCH
          break
          ;;
        *) 
          echo "Invalid selection"
          ;;
      esac
    done
    
    echo -e "''${YELLOW}Selected branch:''${NC} $SELECTED_BRANCH"
    
    # Temporäres Verzeichnis erstellen und Repository klonen
    echo -e "''${YELLOW}Cloning repository...''${NC}"
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    if ! git clone --depth 1 --branch "$SELECTED_BRANCH" "$REPO_URL" "$TEMP_DIR"; then
      echo -e "''${RED}Failed to clone repository!''${NC}"
      exit 1
    fi
    
    # Backup-Verzeichnis erstellen und Backup machen
    BACKUP_DIR="''${BACKUP_ROOT}/$(date +%Y-%m-%d_%H-%M-%S)"
    echo -e "''${YELLOW}Creating backup in: $BACKUP_DIR''${NC}"
    
    # Backup-Verzeichnis vorbereiten
    mkdir -p "$BACKUP_ROOT"
    
    # Alte Backups aufräumen (behalte die letzten 5)
    cleanup_old_backups() {
      local keep=5
      echo -e "''${YELLOW}Cleaning up old backups (keeping last $keep)...''${NC}"
      ls -dt "''${BACKUP_ROOT}"/* | tail -n +$((keep + 1)) | xargs -r rm -rf
    }
    
    # Backup durchführen
    if cp -r "$NIXOS_DIR" "$BACKUP_DIR"; then
      echo -e "''${GREEN}Backup created successfully''${NC}"
      cleanup_old_backups
    else
      echo -e "''${RED}Failed to create backup!''${NC}"
      exit 1
    fi
    
    # Dateien aktualisieren
    echo -e "''${YELLOW}Updating NixOS configuration...''${NC}"
    rm -rf "''${NIXOS_DIR}/modules" "''${NIXOS_DIR}/flake.nix"
    cp -r "''${TEMP_DIR}/nixos/modules" "$NIXOS_DIR/"
    cp "''${TEMP_DIR}/nixos/flake.nix" "$NIXOS_DIR/"
    
    # Berechtigungen setzen
    echo -e "''${YELLOW}Setting permissions...''${NC}"
    chown -R root:root "''${NIXOS_DIR}/modules" "''${NIXOS_DIR}/flake.nix"
    chmod -R 644 "''${NIXOS_DIR}/modules" "''${NIXOS_DIR}/flake.nix"
    find "''${NIXOS_DIR}/modules" -type d -exec chmod 755 {} \;
    
    echo -e "''${GREEN}Update completed successfully!''${NC}"
    echo -e "''${YELLOW}Backup created in: $BACKUP_DIR''${NC}"
    echo -e "''${YELLOW}You can now run 'sudo nixos-rebuild switch' to apply changes.''${NC}"
  '';

in {
  config = {
    environment.systemPackages = [
      update-flake
      pkgs.git
    ];
    
    system.activationScripts.nixosBackupDir = ''
      mkdir -p /var/backup/nixos
      chmod 700 /var/backup/nixos
      chown root:root /var/backup/nixos
    '';
  };
}