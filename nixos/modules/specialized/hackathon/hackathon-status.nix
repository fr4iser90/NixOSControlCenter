{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # Finde Hackathon-Admin-Benutzer
  hackathonUsers = lib.filterAttrs
    (name: user: user.role == "hackathon-admin")
    (getModuleConfig "user");
  
  hasHackathonUsers = (lib.length (lib.attrNames hackathonUsers)) > 0;
  hackathonUser = if hasHackathonUsers then lib.head (lib.attrNames hackathonUsers) else "";

  hackathon-status = pkgs.writeScriptBin "hackathon-status" ''
    #!${pkgs.bash}/bin/bash
    
    # Farben
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    NC='\033[0m'

    # Konfiguration
    HACKATHON_USER="${hackathonUser}"
    HACKATHON_HOME="/home/$HACKATHON_USER"
    HACKATHON_DIR="$HACKATHON_HOME/hackathon"
    DOCKER_COMPOSE_FILE="$HACKATHON_DIR/docker/docker-compose.yml"
    
    # Prüfe ob der richtige User das Script ausführt
    if [ "$(whoami)" != "$HACKATHON_USER" ]; then
      echo -e "''${RED}Error: This script must be run as $HACKATHON_USER''${NC}"
      exit 1
    fi
    
    # Prüfe ob Docker-Compose-Datei existiert
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo -e "''${RED}Docker Compose file not found: $DOCKER_COMPOSE_FILE''${NC}"
        echo -e "''${YELLOW}Please run hackathon-fetch and hackathon-create first''${NC}"
        exit 1
    fi
    
    echo -e "''${BLUE}=== Hackathon Platform Status ===''${NC}"
    
    # Zeige laufende Container
    echo -e "''${YELLOW}Running containers:''${NC}"
    cd "$HACKATHON_DIR/docker"
    docker-compose ps
    
    # Zeige Ressourcennutzung
    echo -e "\n''${YELLOW}Resource usage:''${NC}"
    docker stats --no-stream $(docker-compose ps -q)
    
    # Zeige Traefik-Routen
    echo -e "\n''${YELLOW}Active routes:''${NC}"
    if docker ps | grep -q traefik; then
      curl -s http://localhost:8080/api/http/routers | jq '.[] | {name: .name, rule: .rule, service: .service}'
    else
      echo -e "''${RED}Traefik not running''${NC}"
    fi
    
    # Zeige aktive Hackathons
    echo -e "\n''${YELLOW}Active hackathons:''${NC}"
    if docker ps | grep -q postgres; then
      docker exec $(docker-compose ps -q postgres) psql -U hackathon -c "SELECT id, name, start_date, end_date, status FROM hackathons;"
    else
      echo -e "''${RED}Database not running''${NC}"
    fi
    
    echo -e "\n''${GREEN}Status check completed.''${NC}"
  '';

in {
  environment.systemPackages = if hasHackathonUsers then [
    hackathon-status
    pkgs.jq
  ] else [];
}
