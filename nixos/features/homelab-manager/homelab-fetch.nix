{ config, lib, pkgs, systemConfig, ... }:

let
  # Check if Swarm is active
  isSwarmMode = (systemConfig.homelab.swarm or null) != null;
  
  # Find virtualization users (preferred)
  virtUsers = lib.filterAttrs 
    (name: user: user.role == "virtualization") 
    systemConfig.users;
  
  # Fallback: Find admin users if no virtualization user
  adminUsers = lib.filterAttrs 
    (name: user: user.role == "admin") 
    systemConfig.users;
  
  hasVirtUsers = (lib.length (lib.attrNames virtUsers)) > 0;
  hasAdminUsers = (lib.length (lib.attrNames adminUsers)) > 0;
  
  # Fallback: Admin user if no virtualization user (only for Single-Server)
  virtUser = if hasVirtUsers then 
    (lib.head (lib.attrNames virtUsers))
  else if (hasAdminUsers && !isSwarmMode) then
    (lib.head (lib.attrNames adminUsers))  # Only if NOT Swarm
  else null;
  
  homelab-fetch = pkgs.writeScriptBin "homelab-fetch" ''
    #!${pkgs.bash}/bin/bash
    
    # Konfiguration
    REPO_URL="https://github.com/fr4iser90/NCC-HomeLab.git"
    HOMELAB_PATH="app/shell/install/homelab" # not needed anymore
    TEMP_DIR="/tmp/homelab-fetch"
    VIRT_HOME="/home/${virtUser}"
    
    # Farben
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    NC='\033[0m'
    
    # Prüfe ob der richtige User das Script ausführt
    if [ "$(whoami)" != "${virtUser}" ]; then
      echo -e "''${RED}Error: This script must be run as ${virtUser}''${NC}"
      exit 1
    fi
    
    # Rest des Scripts nur ausführen wenn als richtiger User
    echo -e "''${YELLOW}Fetching homelab configuration...''${NC}"
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    if ! git clone --depth 1 --branch main "$REPO_URL" "$TEMP_DIR"; then
      echo -e "''${RED}Failed to clone repository!''${NC}"
      exit 1
    fi
    
    cd "$VIRT_HOME"
    cp -r "$TEMP_DIR"/* "$VIRT_HOME/"
    
    # Berechtigungen setzen für alle kopierten Dateien
    find "$VIRT_HOME" -type d -exec chmod 755 {} \;
    find "$VIRT_HOME" -type f -exec chmod 644 {} \;
    find "$VIRT_HOME" -type f \( -name "*.key" -o -name "*.pem" -o -name "*.crt" -o -name "*.json" \) -exec chmod 600 {} \;
    
    rm -rf "$TEMP_DIR"
    echo -e "''${GREEN}Homelab fetch completed successfully!''${NC}"

        # Frage nach homelab-create
    echo -e "''${YELLOW}Would you like to run homelab-create now? [Y/n]''${NC}"
    read -r response
    response=''${response:-Y}  # Default to Y if empty
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
      if command -v homelab-create &> /dev/null; then
        echo -e "''${GREEN}Starting homelab-create...''${NC}"
        homelab-create
      else
        echo -e "''${RED}homelab-create command not found!''${NC}"
        exit 1
      fi
    else
      echo -e "''${YELLOW}Skipping homelab-create. You can run it later with: homelab-create''${NC}"
    fi
  '';


in {
  environment.systemPackages = [
    homelab-fetch
    pkgs.git
  ];
}
