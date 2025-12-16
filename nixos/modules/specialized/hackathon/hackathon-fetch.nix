{ config, lib, pkgs, systemConfig, ... }:

let
  # Finde Hackathon-Admin-Benutzer
  hackathonUsers = lib.filterAttrs 
    (name: user: user.role == "hackathon-admin") 
    systemConfig.core.base.user;
  
  hasHackathonUsers = (lib.length (lib.attrNames hackathonUsers)) > 0;
  hackathonUser = if hasHackathonUsers then lib.head (lib.attrNames hackathonUsers) else "";
  
  hackathon-fetch = pkgs.writeScriptBin "hackathon-fetch" ''
    #!${pkgs.bash}/bin/bash
    
    # Konfiguration
    REPO_URL="https://github.com/fr4iser90/NCC-Hackathon.git"
    TEMP_DIR="/tmp/hackathon-fetch"
    HACKATHON_HOME="/home/${hackathonUser}"
    
    # Farben
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    NC='\033[0m'
    
    # Prüfe ob der richtige User das Script ausführt
    if [ "$(whoami)" != "${hackathonUser}" ]; then
      echo -e "''${RED}Error: This script must be run as ${hackathonUser}''${NC}"
      exit 1
    fi
    
    # Rest des Scripts nur ausführen wenn als richtiger User
    echo -e "''${YELLOW}Fetching hackathon platform configuration...''${NC}"
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    if ! git clone --depth 1 --branch main "$REPO_URL" "$TEMP_DIR"; then
      echo -e "''${RED}Failed to clone repository!''${NC}"
      exit 1
    fi
    
    cd "$HACKATHON_HOME"
    mkdir -p "$HACKATHON_HOME/hackathon"
    cp -r "$TEMP_DIR"/* "$HACKATHON_HOME/hackathon/"
    
    # Berechtigungen setzen für alle kopierten Dateien
    find "$HACKATHON_HOME/hackathon" -type d -exec chmod 755 {} \;
    find "$HACKATHON_HOME/hackathon" -type f -exec chmod 644 {} \;
    find "$HACKATHON_HOME/hackathon" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod 755 {} \;
    
    rm -rf "$TEMP_DIR"
    echo -e "''${GREEN}Hackathon platform fetch completed successfully!''${NC}"

    # Frage nach hackathon-create
    echo -e "''${YELLOW}Would you like to run hackathon-create now? [Y/n]''${NC}"
    read -r response
    response=''${response:-Y}  # Default to Y if empty
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
      if command -v hackathon-create &> /dev/null; then
        echo -e "''${GREEN}Starting hackathon-create...''${NC}"
        hackathon-create
      else
        echo -e "''${RED}hackathon-create command not found!''${NC}"
        exit 1
      fi
    else
      echo -e "''${YELLOW}Skipping hackathon-create. You can run it later with: hackathon-create''${NC}"
    fi
  '';

in {
  environment.systemPackages = if hasHackathonUsers then [
    hackathon-fetch
    pkgs.git
  ] else [];
}
