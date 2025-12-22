{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # Finde Hackathon-Admin-Benutzer
  hackathonUsers = lib.filterAttrs
    (name: user: user.role == "hackathon-admin")
    (getModuleConfig "user");
  
  hasHackathonUsers = (lib.length (lib.attrNames hackathonUsers)) > 0;
  hackathonUser = if hasHackathonUsers then lib.head (lib.attrNames hackathonUsers) else "";

  hackathon-create = pkgs.writeScriptBin "hackathon-create" ''
    #!${pkgs.bash}/bin/bash
    
    # Farben
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    NC='\033[0m'

    USER_UID=$(id -u $USER)
    USER_GID=$(id -g $USER)

    # Exportieren der Variablen
    export USER_UID
    export USER_GID

    # Konfiguration
    HACKATHON_USER="${hackathonUser}"
    HACKATHON_HOME="/home/$HACKATHON_USER"
    HACKATHON_DIR="$HACKATHON_HOME/hackathon"
    HACKATHON_SCRIPTS_DIR="$HACKATHON_DIR/scripts"
    HACKATHON_EMAIL="${systemConfig.email}"
    HACKATHON_DOMAIN="${systemConfig.domain}"
    
    # Debug: Zeige Konfigurationswerte
    echo "Debug: HACKATHON_USER=$HACKATHON_USER"
    echo "Debug: HACKATHON_HOME=$HACKATHON_HOME"
    
    # Prüfe ob der richtige User das Script ausführt
    if [ "$(whoami)" != "$HACKATHON_USER" ]; then
      echo -e "''${RED}Error: This script must be run as $HACKATHON_USER''${NC}"
      exit 1
    fi
    
    echo -e "''${YELLOW}Creating new hackathon environment...''${NC}"
    
    # Prüfe ob Hackathon-Verzeichnis existiert
    if [[ ! -d "$HACKATHON_DIR" ]]; then
        echo -e "''${RED}Hackathon directory not found: $HACKATHON_DIR''${NC}"
        echo -e "''${YELLOW}Please run hackathon-fetch first''${NC}"
        exit 1
    fi

    echo -e "''${YELLOW}Updating configuration files...''${NC}"
    
    # Update Konfigurationsdateien
    find "$HACKATHON_DIR" \
        -type f \( -name "*.yml" -o -name "*.env" -o -name "*.json" \) \
        -exec sed -i \
            -e "s|{{EMAIL}}|$HACKATHON_EMAIL|g" \
            -e "s|{{DOMAIN}}|$HACKATHON_DOMAIN|g" \
            -e "s|{{USER}}|$HACKATHON_USER|g" \
            -e "s|{{UID}}|$USER_UID|g" \
            -e "s|{{GID}}|$USER_GID|g" \
            {} \;
    
    # Führe Init-Script aus, falls vorhanden
    INIT_SCRIPT="$HACKATHON_SCRIPTS_DIR/init-hackathon.sh"
    if [ -f "$INIT_SCRIPT" ]; then
      echo -e "''${YELLOW}Running initialization script...''${NC}"
      export DOMAIN=${systemConfig.domain}
      export EMAIL=${systemConfig.email}
      bash "$INIT_SCRIPT"
      echo -e "''${GREEN}Hackathon environment created successfully!''${NC}"
    else
      echo -e "''${RED}Error: init-hackathon.sh not found!''${NC}"
      echo -e "''${YELLOW}Please run hackathon-fetch first''${NC}"
      exit 1
    fi
  '';

in {
  environment.systemPackages = if hasHackathonUsers then [
    hackathon-create
  ] else [];
}
