{ config, lib, pkgs, systemConfig, ... }:

let
  # Debug-Ausgaben mit unterschiedlichen Namen
  debug1 = builtins.trace "Available users: ${toString (lib.attrNames systemConfig.users)}" null;
  debug2 = builtins.trace "Users structure: ${builtins.toJSON systemConfig.users}" null;

  # Finde Virtualisierungsbenutzer
  virtUsers = lib.filterAttrs 
    (name: user: 
      let
        debug3 = builtins.trace "Checking user ${name} with role ${user.role}" null;
      in 
      user.role == "virtualization"
    ) 
    systemConfig.users;
  
  debug4 = builtins.trace "Found virt users: ${toString (lib.attrNames virtUsers)}" null;
  
  hasVirtUsers = (lib.length (lib.attrNames virtUsers)) > 0;
  virtUser = lib.head (lib.attrNames virtUsers);

  debug5 = builtins.trace "Selected virtUser: ${virtUser}" null;

  homelab-create = pkgs.writeScriptBin "homelab-create" ''
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
    VIRT_USER="${virtUser}"
    VIRT_HOME="/home/$VIRT_USER"
    DOCKER_DIR="$VIRT_HOME/docker"
    DOCKER_SCRIPTS_DIR="$VIRT_HOME/docker-scripts"
    HOMELAB_EMAIL="${systemConfig.email}"
    HOMELAB_DOMAIN="${systemConfig.domain}"
    
    # Debug: Zeige Konfigurationswerte
    echo "Debug: VIRT_USER=$VIRT_USER"
    echo "Debug: VIRT_HOME=$VIRT_HOME"
    
    # Prüfe ob der richtige User das Script ausführt
    if [ "$(whoami)" != "$VIRT_USER" ]; then
      echo -e "''${RED}Error: This script must be run as $VIRT_USER''${NC}"
      exit 1
    fi
    
    echo -e "''${YELLOW}Creating new homelab environment...''${NC}"
    
    # Prüfe ob Container-Verzeichnis existiert
    if [[ ! -d "$DOCKER_DIR" ]]; then
        echo -e "''${RED}Container directory not found: $DOCKER_DIR''${NC}"
        echo -e "''${YELLOW}Please run homelab-fetch first''${NC}"
        exit 1
    fi

    echo -e "''${YELLOW}Updating configuration files...''${NC}"
    
    # Update Konfigurationsdateien
    find "$DOCKER_DIR" \
        -type f \( -name "*.yml" -o -name "*.env" \) \
        -exec sed -i \
            -e "s|{{EMAIL}}|$HOMELAB_EMAIL|g" \
            -e "s|{{DOMAIN}}|$HOMELAB_DOMAIN|g" \
            -e "s|{{USER}}|$VIRT_USER|g" \
            -e "s|{{UID}}|$USER_UID|g" \
            -e "s|{{GID}}|$USER_GID|g" \
            {} \;
    
    # Führe Init-Script aus, falls vorhanden
    INIT_SCRIPT="$DOCKER_SCRIPTS_DIR/bin/init-homelab.sh"
    if [ -f "$INIT_SCRIPT" ]; then
      echo -e "''${YELLOW}Running initialization script...''${NC}"
      export DOMAIN=${systemConfig.domain}
      export EMAIL=${systemConfig.email}
      bash "$INIT_SCRIPT"
      echo -e "''${GREEN}Homelab environment created successfully!''${NC}"
      
      # Prompt to disable desktop environment
      echo -e "''${YELLOW}Do you want to disable the desktop environment by running 'sudo ncc homelab-minimize'?''${NC}"
      read -p "Type 'y' for yes or 'n' for no: " response

      if [[ "$response" =~ ^[Yy]$ ]]; then
          echo -e "''${YELLOW}Disabling desktop environment...''${NC}"
          sudo ncc homelab-minimize
      else
          echo -e "''${YELLOW}Skipping desktop environment disable. You can run 'sudo ncc homelab-minimize' later if needed.''${NC}"
      fi
    else
      echo -e "''${RED}Error: init-homelab.sh not found!''${NC}"
      echo -e "''${YELLOW}Please run homelab-fetch first''${NC}"
      exit 1
    fi
  '';

in {
  environment.systemPackages = if hasVirtUsers then [
    homelab-create
  ] else [];
}