{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = config.features.homelab-manager;
  
  # Finde Virtualisierungsbenutzer
  virtUsers = lib.filterAttrs 
    (name: user: user.role == "virtualization") 
    systemConfig.users;

  hasVirtUsers = (lib.length (lib.attrNames virtUsers)) > 0;
  virtUser = lib.head (lib.attrNames virtUsers);
  domain = systemConfig.domain
in {
  options.features.homelab-manager = {
    enable = lib.mkEnableOption "Homelab Manager";
    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable debug output";
    };

    repoUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/fr4iser90/NixOsControlCenter.git";
      description = "URL of the homelab repository";
    };

    homelabPath = lib.mkOption {
      type = lib.types.str;
      default = "app/shell/install/homelab";
      description = "Path to homelab files in repository";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Git branch to use";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "example.com";
      description = "Base domain for homelab services";
    };
  };

  config = lib.mkIf (cfg.enable && hasVirtUsers) {
    features.terminal-ui.enable = true;

    environment.systemPackages = let
      ui = config.features.terminal-ui.api;
      
      homelab-fetch = pkgs.writeScriptBin "homelab-fetch" ''
        #!${pkgs.bash}/bin/bash
        
        # Konfiguration
        REPO_URL="${cfg.repoUrl}"
        HOMELAB_PATH="${cfg.homelabPath}"
        TEMP_DIR="/tmp/homelab-fetch"
        VIRT_HOME="/home/${virtUser}"
        
        # Prüfe ob der richtige User das Script ausführt
        if [ "$(whoami)" != "${virtUser}" ]; then
          ${ui.messages.error "This script must be run as ${virtUser}"}
          exit 1
        fi
        
        # Rest des Scripts nur ausführen wenn als richtiger User
        ${ui.messages.info "Fetching homelab configuration..."}
        rm -rf "$TEMP_DIR"
        mkdir -p "$TEMP_DIR"
        
        if ! git clone --depth 1 --branch ${cfg.branch} "$REPO_URL" "$TEMP_DIR"; then
          ${ui.messages.error "Failed to clone repository!"}
          exit 1
        fi
        
        cd "$VIRT_HOME"
        cp -r "$TEMP_DIR/$HOMELAB_PATH"/* "$VIRT_HOME/"
        
        # Berechtigungen setzen für alle kopierten Dateien
        find "$VIRT_HOME" -type d -exec chmod 755 {} \;
        find "$VIRT_HOME" -type f -exec chmod 644 {} \;
        find "$VIRT_HOME" -type f \( -name "*.key" -o -name "*.pem" -o -name "*.crt" -o -name "*.json" \) -exec chmod 600 {} \;
        
        rm -rf "$TEMP_DIR"
        ${ui.badges.success "Homelab fetch completed successfully!"}

        # Frage nach homelab-create
        ${ui.prompts.confirm "Would you like to run homelab-create now?" "y"}
        read -r response
        response=''${response:-y}
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
          if command -v homelab-create &> /dev/null; then
            ${ui.messages.info "Starting homelab-create..."}
            homelab-create
          else
            ${ui.messages.error "homelab-create command not found!"}
            exit 1
          fi
        else
          ${ui.messages.info "Skipping homelab-create. You can run it later with: homelab-create"}
        fi
      '';

      homelab-create = pkgs.writeScriptBin "homelab-create" ''
        #!${pkgs.bash}/bin/bash
        
        # Konfiguration
        VIRT_USER="${virtUser}"
        VIRT_HOME="/home/$VIRT_USER"
        DOCKER_DIR="$VIRT_HOME/docker"
        DOCKER_SCRIPTS_DIR="$VIRT_HOME/docker-scripts"
        HOMELAB_EMAIL="${systemConfig.email}"
        HOMELAB_DOMAIN="${systemConfig.domain}"
        
        ${if cfg.debug then ''
          ${ui.messages.debug "VIRT_USER=$VIRT_USER"}
          ${ui.messages.debug "VIRT_HOME=$VIRT_HOME"}
        '' else ""}
        
        # Prüfe ob der richtige User das Script ausführt
        if [ "$(whoami)" != "$VIRT_USER" ]; then
          ${ui.messages.error "This script must be run as $VIRT_USER"}
          exit 1
        fi
        
        ${ui.messages.info "Creating new homelab environment..."}
        
        # Prüfe ob Container-Verzeichnis existiert
        if [[ ! -d "$DOCKER_DIR" ]]; then
          ${ui.messages.error "Container directory not found: $DOCKER_DIR"}
          ${ui.messages.warning "Please run homelab-fetch first"}
          exit 1
        fi

        ${ui.messages.info "Updating configuration files..."}
        
        # Update Konfigurationsdateien
        find "$DOCKER_DIR" \
          -type f \( -name "*.yml" -o -name "*.env" \) \
          -exec sed -i \
            -e "s|{{EMAIL}}|$HOMELAB_EMAIL|g" \
            -e "s|{{DOMAIN}}|$HOMELAB_DOMAIN|g" \
            -e "s|{{USER}}|$VIRT_USER|g" \
            {} \;
        
        # Führe Init-Script aus, falls vorhanden
        INIT_SCRIPT="$DOCKER_SCRIPTS_DIR/init-homelab.sh"
        if [ -f "$INIT_SCRIPT" ]; then
          ${ui.messages.info "Running initialization script..."}
          bash "$INIT_SCRIPT"
          ${ui.badges.success "Homelab environment created successfully!"}
        else
          ${ui.messages.error "init-homelab.sh not found!"}
          ${ui.messages.warning "Please run homelab-fetch first"}
          exit 1
        fi
      '';
      
    in [
      homelab-fetch
      homelab-create
      pkgs.git
    ];
  };
}
