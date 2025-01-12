{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.system.postflight;

  # Basis-Skript für Postflight-Checks
  postflightScript = pkgs.writeScriptBin "nixos-postflight" ''
    #!${pkgs.bash}/bin/bash
    set -e
    
    # Color definitions
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
    
    echo -e "''${BLUE}=== NixOS Postflight Checks ===''${NC}"
    
    # Führe alle aktivierten Checks aus
    ${concatStringsSep "\n" (map (check: 
      if cfg.checks.${check}.enable then
        "echo -e \"\\n''${BLUE}Running ${check} check...''${NC}\""
        + "\n${getAttr check cfg.availableChecks} || exit 1"
      else ""
    ) (attrNames cfg.checks))}
    
    echo -e "\\n''${GREEN}✅ All postflight checks passed''${NC}"
  '';

  # Verfügbare Checks
  defaultChecks = {
    passwords = {
      enable = true;
      script = pkgs.writeScript "check-passwords" ''
        #!${pkgs.bash}/bin/bash
        
        # Prüfe Admin-Passwörter
        for user in $(getent group wheel | cut -d: -f4 | tr ',' ' '); do
          if ! getent shadow "$user" | grep -q "^$user:[^\*\!:]"; then
            echo -e "''${YELLOW}⚠️  Admin user '$user' has no valid password!''${NC}"
            
            while true; do
              read -p "Do you want to set a password for $user now? [Y/n/s(skip)] " response
              case $response in
                [Nn]* )
                  echo "Password check failed."
                  exit 1
                  ;;
                [Ss]* )
                  echo "Skipping password for $user"
                  break
                  ;;
                * )
                  if passwd "$user"; then
                    echo -e "''${GREEN}✅ Password set successfully for $user''${NC}"
                    break
                  else
                    echo -e "''${RED}❌ Failed to set password, please try again''${NC}"
                  fi
                  ;;
              esac
            done
          fi
        done
      '';
    };

    filesystem = {
      enable = true;
      script = pkgs.writeScript "check-filesystem" ''
        #!${pkgs.bash}/bin/bash
        
        # Prüfe wichtige Verzeichnisse und Berechtigungen
        echo "Checking critical directories..."
        
        # System Directories
        dirs=(
          "/etc/nixos/secrets:root:root:700"
          "/etc/nixos/secrets/passwords:root:root:700"
        )
        
        # Add user-specific password directories
        for user in $(getent group wheel | cut -d: -f4 | tr ',' ' '); do
          dirs+=("/etc/nixos/secrets/passwords/$user:$user:users:700")
        done
        
        for dir_spec in "''${dirs[@]}"; do
          IFS=: read -r dir owner group perms <<< "$dir_spec"
          
          if [ ! -d "$dir" ]; then
            echo -e "''${YELLOW}⚠️  Creating $dir''${NC}"
            mkdir -p "$dir"
          fi
          
          current_perms=$(stat -c "%a" "$dir")
          current_owner=$(stat -c "%U" "$dir")
          current_group=$(stat -c "%G" "$dir")
          
          if [ "$current_perms" != "$perms" ] || \
             [ "$current_owner" != "$owner" ] || \
             [ "$current_group" != "$group" ]; then
            echo -e "''${YELLOW}⚠️  Fixing permissions for $dir''${NC}"
            chown "$owner:$group" "$dir"
            chmod "$perms" "$dir"
          fi
        done
      '';
    };

    services = {
      enable = true;
      script = pkgs.writeScript "check-services" ''
        #!${pkgs.bash}/bin/bash
        
        # Prüfe kritische Systemdienste
        echo "Checking critical services..."
        
        services=(
          "dbus"
          "systemd-logind"
          "polkit"
        )
        
        for service in "''${services[@]}"; do
          if ! systemctl is-active --quiet "$service"; then
            echo -e "''${RED}❌ Service $service is not running!''${NC}"
            echo "Attempting to start $service..."
            systemctl start "$service" || {
              echo -e "''${RED}Failed to start $service''${NC}"
              exit 1
            }
          fi
        done
      '';
    };
  };

in {
  options = {
    system.postflight = {
      enable = mkEnableOption "system postflight checks";
      
      checks = mkOption {
        type = types.submodule {
          options = mapAttrs (name: _: {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Enable ${name} check";
            };
          }) defaultChecks;
        };
        default = {};
        description = "Enabled postflight checks";
      };
      
      availableChecks = mkOption {
        type = types.attrs;
        default = mapAttrs (_: check: check.script) defaultChecks;
        description = "Available postflight check scripts";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ postflightScript ];
    
    system.activationScripts.postflight = {
      deps = [ "users" "groups" ];
      text = ''
        echo "Running postflight checks..."
        ${postflightScript}/bin/nixos-postflight
      '';
    };
  };
}